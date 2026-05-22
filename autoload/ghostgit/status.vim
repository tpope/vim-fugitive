" autoload/ghostgit/status.vim — Status buffer, summary rendering, staging actions, change events
" Migrated from autoload/fugitive.vim Section: :Gstatus (lines 4195–5383)
" and related change event functions

" ── Constants ───────────────────────────────────────────────────────

let s:file_pattern = '^[A-Z?] .\|^diff --'
let s:file_commit_pattern = s:file_pattern . '\|^\%(\l\{3,\} \)\=[0-9a-f]\{4,\} '
let s:item_pattern = s:file_commit_pattern . '\|^@@'
let s:section_pattern = '^[A-Z][a-z][^:]*$'
let s:section_commit_pattern = s:section_pattern . '\|^commit '
let s:ref_header = '\%(Merge\|Rebase\|Upstream\|Pull\|Push\)'

" ── Change event (was fugitive#DidChange) ──────────────────────────

function! ghostgit#status#DidChange(...) abort
  let bufnr = a:0 ? a:1 : -1
  let soft = a:0 > 1 ? a:2 : 1
  if bufnr is# 0
    call ghostgit#state#SetDidChangeTime()
    call ghostgit#state#ClearHeadCache()
    call ghostgit#config#Expire()
    call ghostgit#state#Expire('remote_headers')
    return ''
  endif
  if bufnr is# -2
    call ghostgit#state#SetDidChangeTime()
    call ghostgit#state#ClearHeadCache()
    call ghostgit#config#Expire()
    call ghostgit#state#Expire('remote_headers')
    return ''
  endif
  let dir = ghostgit#core#GitDir(bufnr)
  if empty(dir)
    return ''
  endif
  call ghostgit#state#SetDidChangeTime()
  call ghostgit#state#ClearHeadCache()
  call ghostgit#config#Expire(dir)
  call ghostgit#state#Expire('remote_headers')
  return ''
endfunction

" ── Expire status ───────────────────────────────────────────────────

function! s:expire_status(bufnr) abort
  if a:bufnr is# -2 || a:bufnr is# 0
    call ghostgit#state#ClearHeadCache()
    call ghostgit#state#SetLastTime()
    return ''
  endif
  let head_file = ghostgit#buffer#Find('.git/HEAD', a:bufnr)
  if !empty(head_file)
    let last_times = ghostgit#state#GetLastTimes()
    let last_times[ghostgit#core#GetTree(a:bufnr) . '/'] = reltime()
    let head_cache = ghostgit#state#GetHeadCache()
    if has_key(head_cache, head_file)
      call remove(head_cache, head_file)
    endif
  endif
  return ''
endfunction

" ── Reload status ───────────────────────────────────────────────────

function! ghostgit#status#Reload(...) abort
  call s:expire_status(-1)
  call s:reload_status_buffer()
  call ghostgit#util#DoAutocmd('User GhostgitChanged')
  return ''
endfunction

function! s:reload_status_buffer() abort
  if get(b:, 'ghostgit_type', '') !=# 'index' || !empty(get(b:, 'ghostgit_loading'))
    return ''
  endif
  let original_lnum = line('.')
  let info = s:stage_info(original_lnum)
  exe ghostgit#status#BufReadStatus(0)
  call setpos('.', [0, s:stage_seek(info, original_lnum), 1, 0])
  return ''
endfunction

function! s:reload_win_status(...) abort
  if get(b:, 'ghostgit_type', '') !=# 'index' || !empty(get(b:, 'ghostgit_loading')) || &modified
    return
  endif
  if !exists('b:ghostgit_status.reltime')
    exe call('s:reload_status_buffer', a:000)
    return
  endif
  let t = b:ghostgit_status.reltime
  let last_time = ghostgit#state#GetLastTime()
  let last_times = ghostgit#state#GetLastTimes()
  if reltimestr(reltime(last_time, t)) =~# '-\|\d\{10\}\.' ||
        \ reltimestr(reltime(get(last_times, ghostgit#core#GetTree() . '/', t), t)) =~# '-\|\d\{10\}\.'
    exe call('s:reload_status_buffer', a:000)
  endif
endfunction

" ── BufReadStatus (was fugitive#BufReadStatus) ──────────────────────

function! ghostgit#status#BufReadStatus(cmdbang) abort
  exe ghostgit#core#VersionCheck()
  if a:cmdbang
    unlet! b:ghostgit_expanded
  endif
  let b:ghostgit_type = 'index'
  let stat = s:StatusRetrieve(bufnr(''))
  try
    let b:ghostgit_loading = stat
    doautocmd <nomodeline> BufReadPre

    setlocal readonly nomodifiable noswapfile nomodeline buftype=nowrite
    call s:MapStatus()

    " Set a loading message while git runs in the background
    setlocal noreadonly modifiable
    call setline(1, ['# Loading git status...'])
    setlocal nomodified readonly nomodifiable

    " s:StatusProcess will call StatusRender when finished.
    return ghostgit#util#DoAutocmd('User GhostgitIndex')
  finally
    " We don't clear b:ghostgit_loading yet, StatusProcess will do it
  endtry
endfunction

" ── Status Retrieve ─────────────────────────────────────────────────

function! s:StatusRetrieve(bufnr, ...) abort
  let amatch = ghostgit#util#Slash(fnamemodify(bufname(a:bufnr), ':p'))
  let dir = ghostgit#core#GitDir(a:bufnr)
  let config = ghostgit#config#Config(dir, function('len'))

  let cmd = [dir]
  if amatch !~# '^ghostgit:' && ghostgit#util#Cpath($GIT_INDEX_FILE !=# '' ? resolve(ghostgit#core#GitIndexFileEnv()) : ghostgit#buffer#Find('.git/index', dir)) !=# ghostgit#util#Cpath(amatch)
    let cmd += [{'env': {'GIT_INDEX_FILE': ghostgit#core#GitPath(amatch)}}]
  endif

  if ghostgit#git#GitVersion(2, 15)
    call add(cmd, '--no-optional-locks')
  endif

  let rev_parse_cmd = cmd + ['rev-parse', '--short', 'HEAD', '--']

  let stat = {'bufnr': a:bufnr, 'reltime': reltime(), 'work_tree': ghostgit#core#WorkTree(dir), 'cmd': cmd, 'config': config}
  if empty(stat.work_tree)
    let stat.rev_parse = call('ghostgit#git#Execute', [rev_parse_cmd, function('s:StatusProcess'), stat] + a:000)
    let stat.status = {}
    let stat.running = stat.rev_parse
  else
    let stat.rev_parse = ghostgit#git#Execute(rev_parse_cmd, function('len'))
    let status_cmd = cmd + ['status', '-bz', ghostgit#git#GitVersion(2, 11) ? '--porcelain=v2' : '--porcelain']
    let stat.status = call('ghostgit#git#Execute', [status_cmd, function('s:StatusProcess'), stat] + a:000)
    let stat.running = stat.status
  endif
  return stat
endfunction

" ── Status Process ──────────────────────────────────────────────────

function! s:StatusProcess(result, stat) abort
  let stat = a:stat
  let status_exec = a:stat.status
  let config = a:stat.config
  let dir = ghostgit#core#GitDir(config)
  try
    let [staged, unstaged, untracked] = [[], [], []]
    let stat.props = {}

    if empty(status_exec)
      let stat.branch = ghostgit#git#Head(0, config)

    elseif status_exec.exit_status
      let stat.error = ghostgit#util#JoinChomp(status_exec.stderr)
      return

    elseif status_exec.args[-1] ==# '--porcelain=v2'
      if has('nvim')
        let lua_res = luaeval('require("ghostgit.status").parse_porcelain_v2(_A)', status_exec.stdout)
        let staged = lua_res.staged
        let unstaged = lua_res.unstaged
        let untracked = lua_res.untracked
        let stat.props = lua_res.props
        let stat.branch = lua_res.branch
      else
        let output = split(tr(join(status_exec.stdout, "\1"), "\1\n", "\n\1"), "\1", 1)[0:-2]
        let i = 0
        while i < len(output)
          let line = output[i]
          let prop = matchlist(line, '# \(\S\+\) \(.*\)')
          if len(prop)
            let stat.props[prop[1]] = prop[2]
          elseif line[0] ==# '?'
            call add(untracked, {'type': 'File', 'status': line[0], 'filename': line[2:-1], 'relative': [line[2:-1]]})
          elseif line[0] !=# '#'
            if line[0] ==# 'u'
              let file = matchstr(line, '^.\{37\} \x\{40,\} \x\{40,\} \x\{40,\} \zs.*$')
            else
              let file = matchstr(line, '^.\{30\} \x\{40,\} \x\{40,\} \zs.*$')
            endif
            if line[0] ==# '2'
              let i += 1
              let file = matchstr(file, ' \zs.*')
              let relative = [file, output[i]]
            else
              let relative = [file]
            endif
            let filename = join(reverse(copy(relative)), ' -> ')
            let sub = matchstr(line, '^[12u] .. \zs....')
            if line[2] !=# '.'
              call add(staged, {'type': 'File', 'status': line[2], 'filename': filename, 'relative': relative, 'submodule': sub})
            endif
            if line[3] !=# '.'
              let sub = matchstr(line, '^[12u] .. \zs....')
              call add(unstaged, {'type': 'File', 'status': get({'C':'M','M':'?','U':'?'}, matchstr(sub, 'S\.*\zs[CMU]'), line[3]), 'filename': file, 'relative': [file], 'submodule': sub})
            endif
          endif
          let i += 1
        endwhile
        let stat.branch = substitute(get(stat.props, 'branch.head', '(unknown)'), '\C^(\%(detached\|unknown\))$', '', '')
      endif

    else
      let output = split(tr(join(status_exec.stdout, "\1"), "\1\n", "\n\1"), "\1", 1)[0:-2]
      while get(output, 0, '') =~# '^\l\+:'
        call remove(output, 0)
      endwhile
      let branch = matchstr(output[0], '^## \zs\S\+\ze\%($\| \[\)')
      if branch =~# '\.\.\.'
        let stat.branch = split(branch, '\.\.\.')[0]
      else
        let stat.branch = branch ==# 'HEAD' ? '' : branch
      endif

      let i = 0
      while i < len(output)
        let line = output[i]
        let file = line[3:-1]
        let i += 1
        if line[2] !=# ' '
          continue
        endif
        if line[0:1] =~# '[RC]'
          let relative = [file, output[i]]
          let i += 1
        else
          let relative = [file]
        endif
        let filename = join(reverse(copy(relative)), ' -> ')
        if line[0] !~# '[ ?!#]'
          call add(staged, {'type': 'File', 'status': line[0], 'filename': filename, 'relative': relative, 'submodule': ''})
        endif
        if line[0:1] ==# '??'
          call add(untracked, {'type': 'File', 'status': line[1], 'filename': filename, 'relative': relative})
        elseif line[1] !~# '[ !#]'
          call add(unstaged, {'type': 'File', 'status': line[1], 'filename': file, 'relative': [file], 'submodule': ''})
        endif
      endwhile
    endif

    let diff_cmd = stat.cmd + ['-c', 'diff.suppressBlankEmpty=false', '-c', 'core.quotePath=false', 'diff', '--color=never', '--no-ext-diff', '--no-prefix']
    let stat.diff = {'Staged': {'stdout': ['']}, 'Unstaged': {'stdout': ['']}}
    if len(staged)
      let stat.diff['Staged'] = ghostgit#git#Execute(diff_cmd + ['--cached'], function('len'))
    endif
    if len(unstaged)
      let stat.diff['Unstaged'] = ghostgit#git#Execute(diff_cmd + ['--'] + map(copy(unstaged), 'stat.work_tree . "/" . v:val.relative[0]'), function('len'))
    endif

    let [stat.staged, stat.unstaged, stat.untracked] = [staged, unstaged, untracked]

    let stat.files = {'Staged': {}, 'Unstaged': {}}
    for dict in staged
      let stat.files['Staged'][dict.filename] = dict
    endfor
    for dict in unstaged
      let stat.files['Unstaged'][dict.filename] = dict
    endfor

    let branch = stat.branch
    let fetch_remote = config.Get('branch.' . branch . '.remote', 'origin')
    let push_remote = config.Get('branch.' . branch . '.pushRemote',
          \ config.Get('remote.pushDefault', fetch_remote))
    if fetch_remote !=# '.' && empty(config.Get('remote.' . fetch_remote . '.fetch'))
      let fetch_remote = ''
    endif
    if push_remote !=# '.' && empty(config.Get('remote.' . push_remote . '.push', config.Get('remote.' . push_remote . '.fetch')))
      let push_remote = ''
    endif
    let stat.fetch_remote = fetch_remote
    let stat.push_remote = push_remote

    if empty(stat.fetch_remote) || empty(branch)
      let stat.merge = ''
    else
      let stat.merge = config.Get('branch.' . branch . '.merge')
    endif

    let push_default = ghostgit#config#Get('push.default', config)
    if empty(push_default)
      let push_default = ghostgit#git#GitVersion(2) ? 'simple' : 'matching'
    endif
    if push_default ==# 'upstream'
      let stat.push = stat.merge
    elseif empty(stat.push_remote) || empty(branch)
      let stat.push = ''
    else
      let stat.push = 'refs/heads/' . branch
    endif

    let stat.pull_type = 'Pull'
    if len(stat.merge)
      let rebase = ghostgit#config#Get('branch.' . branch . '.rebase', config)
      if empty(rebase)
        let rebase = ghostgit#config#Get('pull.rebase', config)
      endif
      if rebase =~# '^\%(true\|yes\|on\|1\|interactive\|merges\|preserve\)$'
        let stat.pull_type = 'Rebase'
      elseif rebase =~# '^\%(false\|no|off\|0\|\)$'
        let stat.pull_type = 'Merge'
      endif
    endif

    " Call Render when processing is complete
    call s:StatusRender(stat)
  catch
    echoerr 'ghostgit: ' . v:exception
  finally
    call setbufvar(stat.bufnr, 'ghostgit_loading', {})
  endtry
endfunction

" ── Status Render ───────────────────────────────────────────────────

function! s:StatusRender(stat) abort
  try
    let stat = a:stat
    call ghostgit#job#Wait(stat.running)
    if has_key(stat, 'error')
      return 'echoerr ' . string('ghostgit: ' . stat.error)
    endif
    let [staged, unstaged, untracked, config] = [stat.staged, stat.unstaged, stat.untracked, stat.config]
    let dir = ghostgit#core#GitDir(config)

    let pull_ref = stat.merge
    if stat.fetch_remote !=# '.'
      let pull_ref = substitute(pull_ref, '^refs/heads/', 'refs/remotes/' . stat.fetch_remote . '/', '')
    endif

    let push_ref = stat.push
    if stat.push_remote !=# '.'
      let push_ref = substitute(pull_ref, '^refs/heads/', 'refs/remotes/' . stat.push_remote . '/', '')
    endif

    let push_short = substitute(push_ref, '^refs/\w\+/', '', '')
    let pull_short = substitute(pull_ref, '^refs/\w\+/', '', '')

    if isdirectory(ghostgit#buffer#Find('.git/rebase-merge/', dir))
      let rebasing_dir = ghostgit#buffer#Find('.git/rebase-merge/', dir)
    elseif isdirectory(ghostgit#buffer#Find('.git/rebase-apply/', dir))
      let rebasing_dir = ghostgit#buffer#Find('.git/rebase-apply/', dir)
    endif

    call ghostgit#job#Wait(stat.rev_parse)
    let head = empty(stat.branch) ? stat.rev_parse.stdout[0] : stat.branch

    let rebasing = []
    let rebasing_head = 'detached HEAD'
    if exists('rebasing_dir') && filereadable(rebasing_dir . 'git-rebase-todo')
      let rebasing_head = substitute(readfile(rebasing_dir . 'head-name')[0], '\C^refs/heads/', '', '')
      let len = len(stat.rev_parse.stdout[0])
      let lines = readfile(rebasing_dir . 'git-rebase-todo')
      if getfsize(rebasing_dir . 'done') > 0
        let done = readfile(rebasing_dir . 'done')
        call map(done, 'substitute(v:val, ''^\l\+\>'', "done", "")')
        let done[-1] = substitute(done[-1], '^\l\+\>', 'stop', '')
        let lines = done + lines
      endif
      call reverse(lines)
      for line in lines
        let match = matchlist(line, '^\(\l\+\)\s\+\(\x\{4,\}\)\s\+\(.*\)')
        if len(match) && match[1] !~# 'exec\|merge\|label'
          call add(rebasing, {'type': 'Rebase', 'status': get(s:rebase_abbrevs, match[1], match[1]), 'commit': strpart(match[2], 0, len), 'subject': match[3]})
        endif
      endfor
    endif

    let sequencing = []
    try
      let sequencer_todo = reverse(readfile(ghostgit#buffer#Find('.git/sequencer/todo', dir)))
    catch
    endtry
    if exists('sequencer_todo')
      for line in sequencer_todo
        let match = matchlist(line, '^\(\l\+\)\s\+\(\x\{4,\}\)\s\+\(.*\)')
        if len(match) && match[1] !~# 'exec\|merge\|label'
          call add(sequencing, {'type': 'Rebase', 'status': get(s:rebase_abbrevs, match[1], match[1]), 'commit': match[2], 'subject': match[3]})
        endif
      endfor
    else
      try
        let merge_msg = get(readfile(ghostgit#buffer#Find('.git/MERGE_MSG', dir), '', 1), 0, '')
      catch
      endtry
    endif
    if exists('merge_msg')
      if filereadable(ghostgit#buffer#Find('.git/CHERRY_PICK_HEAD', dir))
        let pick_head = ghostgit#git#Execute(['rev-parse', '--short', 'CHERRY_PICK_HEAD', '--'], dir).stdout[0]
        if !empty(pick_head)
          call add(sequencing, {'type': 'Rebase', 'status': 'pick', 'commit': pick_head, 'subject': merge_msg})
        endif
      elseif filereadable(ghostgit#buffer#Find('.git/REVERT_HEAD', dir))
        let pick_head = ghostgit#git#Execute(['rev-parse', '--short', 'REVERT_HEAD', '--'], dir).stdout[0]
        if !empty(pick_head)
          call add(sequencing, {'type': 'Rebase', 'status': 'revert', 'commit': pick_head, 'subject': merge_msg})
        endif
      endif
    endif

    let stat.expanded = {'Staged': {}, 'Unstaged': {}}
    let to = {'lines': []}
    call s:AddHeader(to, 'Head', head)
    call s:AddHeader(to, stat.pull_type, pull_short)
    if push_ref !=# pull_ref
      call s:AddHeader(to, 'Push', push_short)
    endif
    if empty(stat.work_tree)
      if get(ghostgit#config#GetAll('core.bare', config), 0, '') !~# '^\%(false\|no|off\|0\|\)$'
        call s:AddHeader(to, 'Bare', 'yes')
      else
        call s:AddHeader(to, 'Error', 'core.worktree is required')
      endif
    endif
    if get(ghostgit#config#GetAll('advice.statusHints', config), 0, 'true') !~# '^\%(false\|no|off\|0\|\)$'
      call s:AddHeader(to, 'Help', 'g?')
    endif

    call s:AddSection(to, 'Rebasing ' . rebasing_head, rebasing)
    call s:AddSection(to, get(get(sequencing, 0, {}), 'status', '') ==# 'revert' ? 'Reverting' : 'Cherry Picking', sequencing)
    call s:AddSection(to, 'Untracked', untracked)
    call s:AddDiffSection(to, stat, 'Unstaged', unstaged)
    call s:AddDiffSection(to, stat, 'Staged', staged)

    let unique_push_ref = push_ref ==# pull_ref ? '' : push_ref
    let unpushed_push = s:QueryLogRange(unique_push_ref, head, dir)
    if get(stat.props, 'branch.ab', '') =~# '^+0 '
      let unpushed_pull = {'error': 0, 'overflow': 0, 'entries': []}
    else
      let unpushed_pull = s:QueryLogRange(pull_ref, head, dir)
    endif
    if unpushed_push.error == 1
      let unpushed_push = unpushed_pull
    endif
    call s:AddLogSection(to, 'Unpushed to ' . push_short, unpushed_push)
    call s:AddLogSection(to, 'Unpushed to ' . pull_short, unpushed_pull)
    if unpushed_push.error && unpushed_pull.error && empty(rebasing) &&
          \ !empty(stat.push_remote . stat.fetch_remote)
      call s:AddLogSection(to, 'Unpushed to *', s:QueryLog([head, '--not', '--remotes'], 256, dir))
    endif

    let bufnr = stat.bufnr
    setlocal noreadonly modifiable
    if len(to.lines) < line('$')
      silent keepjumps execute (len(to.lines)+1) . ',$delete_'
    endif
    call setline(1, to.lines)
    call setbufvar(bufnr, 'ghostgit_status', stat)
    call setbufvar(bufnr, 'ghostgit_expanded', stat.expanded)
    setlocal nomodified readonly nomodifiable

    " Finalize buffer setup after async load
    doautocmd <nomodeline> BufReadPost
    if getbufvar(bufnr, '&bufhidden') ==# ''
      call setbufvar(bufnr, '&bufhidden', 'delete')
    endif
    if !exists('b:dispatch')
      let b:dispatch = ':Git fetch --all'
    endif
    setlocal filetype=ghostgit

    return ''
  finally
    let b:ghostgit_type = 'index'
  endtry
endfunction

function! s:AddHeader(to, key, value) abort
  if empty(a:value)
    return
  endif
  call add(a:to.lines, a:key . ':' . (len(a:value) ? ' ' . a:value : ''))
endfunction

function! s:AddSection(to, label, lines, ...) abort
  let note = a:0 ? a:1 : ''
  if empty(a:lines) && empty(note)
    return
  endif
  call extend(a:to.lines, ['', a:label . (len(note) ? ': ' . note : ' (' . len(a:lines) . ')')] + s:Format(a:lines))
endfunction

function! s:AddDiffSection(to, stat, label, files) abort
  if empty(a:files)
    return
  endif
  let diff_section = a:stat.diff[a:label]
  let expanded = a:stat.expanded[a:label]
  let was_expanded = get(getbufvar(a:stat.bufnr, 'ghostgit_expanded', {}), a:label, {})
  call extend(a:to.lines, ['', a:label . ' (' . len(a:files) . ')'])
  for file in a:files
    call add(a:to.lines, s:Format(file))
    if has_key(was_expanded, file.filename)
      let [diff, start] = s:StageInlineGetDiff(diff_section, file)
      if len(diff)
        let expanded[file.filename] = [start]
        call extend(a:to.lines, diff)
      endif
    endif
  endfor
endfunction

function! s:QueryLog(refspec, limit, dir) abort
  let [log, exec_error] = ghostgit#git#LinesError(['log', '-n', '' . a:limit, '--pretty=format:%h%x09%s'] + a:refspec + ['--'], a:dir)
  call map(log, 'split(v:val, "\t", 1)')
  call map(log, '{"type": "Log", "commit": v:val[0], "subject": join(v:val[1 : -1], "\t")}')
  let result = {'error': exec_error ? 1 : 0, 'overflow': 0, 'entries': log}
  if len(log) == a:limit
    call remove(log, -1)
    let result.overflow = 1
  endif
  return result
endfunction

function! s:QueryLogRange(old, new, dir) abort
  if empty(a:old) || empty(a:new)
    return {'error': 2, 'overflow': 0, 'entries': []}
  endif
  return s:QueryLog([a:old . '..' . a:new], 256, a:dir)
endfunction

function! s:AddLogSection(to, label, log) abort
  if empty(a:log.entries)
    return
  endif
  let label = a:label . ' (' . len(a:log.entries) . (a:log.overflow ? '+' : '') . ')'
  call extend(a:to.lines, ['', label] + s:Format(a:log.entries))
endfunction

function! s:FormatLog(dict) abort
  return a:dict.commit . ' ' . a:dict.subject
endfunction

function! s:FormatRebase(dict) abort
  return a:dict.status . ' ' . a:dict.commit . ' ' . a:dict.subject
endfunction

function! s:FormatFile(dict) abort
  return a:dict.status . ' ' . a:dict.filename
endfunction

function! s:Format(val) abort
  if type(a:val) == type({})
    return s:Format{a:val.type}(a:val)
  elseif type(a:val) == type([])
    return map(copy(a:val), 's:Format(v:val)')
  else
    return '' . a:val
  endif
endfunction

function! s:StageInlineGetDiff(diff_section, info) abort
  let diff = []
  let relative = get(a:info, 'relative', [])
  if empty(relative)
    return [[], -1]
  endif
  if a:info.status ==# 'U'
    let diff_header = 'diff --cc ' . ghostgit#util#Quote(relative[0])
  else
    let diff_header = 'diff --git ' . ghostgit#util#Quote(get(relative, -1, '')) . ' ' . ghostgit#util#Quote(relative[0])
  endif
  let stdout = ghostgit#job#Wait(a:diff_section).stdout
  let start = index(stdout, diff_header)
  if start == -1
    return [[], -1]
  endif
  let index = start + 1
  while get(stdout, index, '@@') !~# '^@@\|^diff '
    let index += 1
  endwhile
  while get(stdout, index, '') =~# '^[@ \+-]'
    call add(diff, stdout[index])
    let index += 1
  endwhile
  return [diff, start]
endfunction

let s:rebase_abbrevs = {
      \ 'p': 'pick',
      \ 'r': 'reword',
      \ 'e': 'edit',
      \ 's': 'squash',
      \ 'f': 'fixup',
      \ 'x': 'exec',
      \ 'd': 'drop',
      \ 'l': 'label',
      \ 't': 'reset',
      \ 'm': 'merge',
      \ 'b': 'break',
      \ }

function! s:MapStatus() abort
  " Map basic status buffer commands
  nnoremap <buffer><silent> gq :if bufnr('$') == 1<Bar>quit<Bar>else<Bar>bdelete<Bar>endif<CR>
  nnoremap <buffer><silent> g? :help ghostgit-maps<CR>
endfunction


" ── Do autocmd changed ──────────────────────────────────────────────

function! s:do_autocmd_changed(dir) abort
  let dir = a:dir is# -2 ? '' : ghostgit#core#GitDir(a:dir)
  if empty(dir) || !exists('#User#GhostgitChanged') || exists('g:ghostgit_event')
    return ''
  endif
  try
    call ghostgit#state#SetEvent(dir, a:dir is# -1 ? {} : a:dir)
    exe ghostgit#util#DoAutocmd('User GhostgitChanged')
  finally
    call ghostgit#state#ClearEvent()
    if dir isnot# ghostgit#core#GitDir()
      let &l:ro = &l:ro
    endif
  endtry
  return ''
endfunction

" ── Stage info ──────────────────────────────────────────────────────

function! s:stage_info(...) abort
  let lnum = a:0 ? a:1 : line('.')
  let sigil = matchstr(getline(lnum), '^[ @\+-]')
  let offset = -1
  if len(sigil)
    let [lnum, old_lnum, new_lnum] = s:hunk_position(lnum)
    let offset = sigil ==# '-' ? old_lnum : new_lnum
    while getline(lnum) =~# '^[ @\+-]'
      let lnum -= 1
    endwhile
  endif
  let slnum = lnum + 1
  let heading = ''
  let index = 0
  while len(getline(slnum - 1)) && empty(heading)
    let slnum -= 1
    let heading = matchstr(getline(slnum), '^\u\l\+.\{-\}\ze (\d\++\=)$')
    if empty(heading) && getline(slnum) !~# '^[ @\+-]'
      let index += 1
    endif
  endwhile
  let text = matchstr(getline(lnum), '^[A-Z?] \zs.*')
  let file = s:status_section_file(heading, text)
  let relative = get(file, 'relative', len(text) ? [text] : [])
  return {'section': matchstr(heading, '^\u\l\+'),
        \ 'heading': heading,
        \ 'sigil': sigil,
        \ 'offset': offset,
        \ 'filename': text,
        \ 'relative': copy(relative),
        \ 'paths': map(copy(relative), 'ghostgit#core#GetTree() . "/" . v:val'),
        \ 'commit': matchstr(getline(lnum), '^\%(\%(\x\x\x\)\@!\l\+\s\+\)\=\zs[0-9a-f]\{4,\}\ze '),
        \ 'status': matchstr(getline(lnum), '^[A-Z?]\ze \|^\%(\x\x\x\)\@!\l\+\ze [0-9a-f]'),
        \ 'submodule': get(file, 'submodule', ''),
        \ 'index': index}
endfunction

function! s:status_section_file(heading, filename) abort
  return get(get(get(get(b:, 'ghostgit_status', {}), 'files', {}), a:heading, {}), a:filename, {})
endfunction

" ── Hunk position ───────────────────────────────────────────────────

function! s:hunk_position(lnum) abort
  let lnum = a:lnum
  let old_lnum = -1
  let new_lnum = -1
  while lnum > 0 && getline(lnum) !~# '^@@'
    let lnum -= 1
  endwhile
  if lnum > 0
    let match = matchlist(getline(lnum), '^@@ -\(\d\+\),\=\(\d*\) +\(\d\+\),\=\(\d*\) @@')
    if len(match)
      let old_lnum = +match[1]
      let new_lnum = +match[3]
    endif
  endif
  return [lnum, old_lnum, new_lnum]
endfunction

" ── Stage seek ──────────────────────────────────────────────────────

function! s:stage_seek(info, fallback) abort
  let info = a:info
  if empty(info.heading)
    return a:fallback
  endif
  let line = search('^' . escape(info.heading, '^$.*[]~\') . ' (\d\++\=)$', 'wn')
  if !line
    for section in get({'Staged': ['Unstaged', 'Untracked'], 'Unstaged': ['Untracked', 'Staged'], 'Untracked': ['Unstaged', 'Staged']}, info.section, [])
      let line = search('^' . section, 'wn')
      if line
        return line + (info.index > 0 ? 1 : 0)
      endif
    endfor
    return 1
  endif
  let i = 0
  while len(getline(line))
    let filename = matchstr(getline(line), '^[A-Z?] \zs.*')
    if len(filename) &&
          \ ((info.filename[-1:-1] ==# '/' && filename[0 : len(info.filename) - 1] ==# info.filename) ||
          \ (filename[-1:-1] ==# '/' && filename ==# info.filename[0 : len(filename) - 1]) ||
          \ filename ==# info.filename)
      if info.offset < 0
        return line
      else
        if getline(line+1) !~# '^@'
          exe s:stage_inline('show', line)
        endif
        if getline(line+1) !~# '^@'
          return line
        endif
        let type = info.sigil ==# '-' ? '-' : '+'
        let offset = -1
        while offset < info.offset
          let line += 1
          if getline(line) =~# '^@'
            let offset = +matchstr(getline(line), type . '\zs\d\+') - 1
          elseif getline(line) =~# '^[ ' . type . ']'
            let offset += 1
          elseif getline(line) !~# '^[ @\+-]'
            return line - 1
          endif
        endwhile
        return line
      endif
    endif
    let commit = matchstr(getline(line), '^\%(\%(\x\x\x\)\@!\l\+\s\+\)\=\zs[0-9a-f]\+')
    if len(commit) && commit ==# info.commit
      return line
    endif
    if i ==# info.index
      let backup = line
    endif
    let i += getline(line) !~# '^[ @\+-]'
    let line += 1
  endwhile
  return exists('backup') ? backup : line - 1
endfunction

function! s:stage_inline(mode, ...) abort
  return ''
endfunction

function! s:stage_reveal() abort
  return ''
endfunction

" ── Efm dir ─────────────────────────────────────────────────────────

function! ghostgit#status#EfmDir(...) abort
  let dir = matchstr(a:0 ? a:1 : &errorformat, '\c,%\\&\%(git\|ghostgit\)_\=dir=\zs\%(\\.\|[^,]\)*')
  let dir = substitute(dir, '%%', '%', 'g')
  let dir = substitute(dir, '\\\ze[\,]', '', 'g')
  return dir
endfunction

" ── Statusline ──────────────────────────────────────────────────────

function! ghostgit#statusline#Statusline(...) abort
  let dir = ghostgit#core#GitDir(bufnr(''))
  if empty(dir)
    return ''
  endif
  let status = ''
  let commit = ghostgit#core#DirCommitFile(@%)[1]
  if len(commit)
    let status .= ':' . commit[0:6]
  endif
  let status .= '(' . ghostgit#git#Head(7, dir) . ')'
  return '[Git' . status . ']'
endfunction

function! ghostgit#statusline#Foldtext() abort
  if &foldmethod !=# 'syntax'
    return foldtext()
  endif

  let line_foldstart = getline(v:foldstart)
  if line_foldstart =~# '^diff '
    let [add, remove] = [-1, -1]
    let filename = ''
    for lnum in range(v:foldstart, v:foldend)
      let line = getline(lnum)
      if filename ==# '' && line =~# '^[+-]\{3\} "\=[abciow12]/'
        let filename = ghostgit#util#Unquote(line[4:-1])[2:-1]
      endif
      if line =~# '^+'
        let add += 1
      elseif line =~# '^-'
        let remove += 1
      elseif line =~# '^Binary '
        let binary = 1
      endif
    endfor
    if filename ==# ''
      let filename = ghostgit#util#Unquote(matchstr(line_foldstart, '^diff .\{-\} \zs"\=[abciow12]/\zs.*\ze "\=[abciow12]/'))[2:-1]
    endif
    if filename ==# ''
      let filename = line_foldstart[5:-1]
    endif
    if exists('binary')
      return 'Binary: '.filename
    else
      return '+-' . v:folddashes . ' ' . (add<10&&remove<100?' ':'') . add . '+ ' . (remove<10&&add<100?' ':'') . remove . '- ' . filename
    endif
  elseif line_foldstart =~# '^@@\+ .* @@'
    return '+-' . v:folddashes . ' ' . line_foldstart
  elseif &filetype ==# 'ghostgit' && line_foldstart =~# '^[A-Z][a-z].* (\d\+)$'
    let c = +matchstr(line_foldstart, '(\zs\d\+\ze)$')
    return '+-' . v:folddashes . printf('%3d item', c) . (c == 1 ? ':  ' : 's: ') . matchstr(line_foldstart, '.*\ze (\d\+)$')
  elseif &filetype ==# 'gitcommit' && line_foldstart =~# '^# .*:$'
    let lines = getline(v:foldstart, v:foldend)
    call filter(lines, 'v:val =~# "^#\t"')
    call map(lines, "ghostgit#util#Sub(v:val, '^#\t%(modified: +|renamed: +)=', '')")
    call map(lines, "ghostgit#util#Sub(v:val, '^([[:alpha:] ]+): +(.*)', '\\2 (\\1)')")
    return line_foldstart.' '.join(lines, ', ')
  endif
  return foldtext()
endfunction
