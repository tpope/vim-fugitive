" autoload/ghostgit/command.vim — :Git command, all :G* commands, completion
" Migrated from autoload/fugitive.vim Section: :Git (lines 3418–4178)
" and all command handler sections

" ── Bang edits mapping ──────────────────────────────────────────────

let s:bang_edits = {'split': 'Git', 'vsplit': 'vertical Git', 'tabedit': 'tab Git', 'pedit': 'Git!'}

" ── Main Git command ────────────────────────────────────────────────

function! ghostgit#command#Git(line1, line2, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let arg = a:arg
  let post = ''

  " Handle ++curwin and other modifiers
  if arg =~# '^++curwin'
    let arg = strpart(arg, 8)
    let mods = 'keepalt ' . a:mods
  else
    let mods = a:mods
  endif

  " Handle +cmd
  if arg =~# '^+'
    let post = matchstr(arg, '^+\zs\S.*')
    let arg = matchstr(arg, '^\S\+')
  endif

  let args = split(arg, '\s\+')
  let subcommand = get(args, 0, '')

  if empty(subcommand)
    return ghostgit#command#Status(a:line1, a:line2, a:range, a:bang, mods, arg)
  endif

  " Dispatch to subcommand handlers
  if subcommand ==# 'status'
    return ghostgit#command#Status(a:line1, a:line2, a:range, a:bang, mods, arg)
  elseif subcommand ==# 'commit'
    return ghostgit#command#Commit(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'revert'
    return ghostgit#command#Revert(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'merge'
    return ghostgit#command#Merge(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'rebase'
    return ghostgit#command#Rebase(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'pull'
    return ghostgit#command#Pull(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'push'
    return ghostgit#command#Push(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'fetch'
    return ghostgit#command#Fetch(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'blame'
    return ghostgit#command#Blame(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'bisect'
    return ghostgit#command#Bisect(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'difftool'
    return ghostgit#command#Difftool(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'mergetool'
    return ghostgit#command#Mergetool(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'grep'
    return ghostgit#command#Grep(a:line1, a:line2, a:range, a:bang, mods, args)
  elseif subcommand ==# 'log'
    return ghostgit#command#Log(a:line1, a:line2, a:range, a:bang, mods, args)
  else
    return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, mods, args)
  endif
endfunction

" ── Status ──────────────────────────────────────────────────────────

function! ghostgit#command#Status(line1, line2, range, bang, mods, arg) abort
  let dir = ghostgit#core#GitDir()
  exe ghostgit#core#DirCheck(dir)
  try
    let mods = ghostgit#util#Mods(a:mods, 'Edge')
    let file = ghostgit#buffer#Find(':', dir)
    let arg = ' +setl\ foldmarker=<<<<<<<<,>>>>>>>>\|let\ w:ghostgit_status=ghostgit#core#GitDir() ' .
          \ ghostgit#util#FnameEscape(file)
    for tabnr in [tabpagenr()] + (mods =~# '\<tab\>' ? range(1, tabpagenr('$')) : [])
      let bufs = tabpagebuflist(tabnr)
      for winnr in range(1, tabpagewinnr(tabnr, '$'))
        if ghostgit#util#Cpath(file, fnamemodify(bufname(bufs[winnr-1]), ':p'))
          if tabnr == tabpagenr() && winnr == winnr()
            call ghostgit#status#Reload()
          else
            call ghostgit#status#DidChange(dir)
            exe tabnr . 'tabnext'
            exe winnr . 'wincmd w'
          endif
          let w:ghostgit_status = dir
          1
          return ''
        endif
      endfor
    endfor
    if a:range ==# 0
      return mods . 'edit' . (a:bang ? '!' : '') . arg
    elseif a:bang
      return mods . 'pedit' . arg . '|wincmd P'
    else
      return mods . 'keepalt split' . arg
    endif
  catch /^ghostgit:/
    return 'echoerr ' . string(v:exception)
  endtry
  return ''
endfunction

" ── Run generic git command ─────────────────────────────────────────

function! ghostgit#command#Run(line1, line2, range, bang, mods, args) abort
  let dir = ghostgit#core#GitDir()
  exe ghostgit#core#DirCheck(dir)
  let cmd = a:args
  let state = {'git_dir': dir, 'args': cmd, 'mods': a:mods, 'bang': a:bang}

  " Build the command
  let git_cmd = ghostgit#git#GitCmd()
  let tree = ghostgit#core#GetTree(dir)
  if empty(tree)
    let full_cmd = git_cmd + ['--git-dir=' . ghostgit#core#GitPath(dir)] + cmd
  else
    let dir_args = ['-C', ghostgit#core#GitPath(tree)]
    if !ghostgit#util#Cpath(tree . '/.git', dir) || len($GIT_DIR)
      let dir_args += ['--git-dir=' . ghostgit#core#GitPath(dir)]
    endif
    let full_cmd = git_cmd + dir_args + cmd
  endif

  " Execute
  let result = ghostgit#git#Execute(full_cmd)
  call ghostgit#status#DidChange(result)
  return ''
endfunction

" ── Open buffer ─────────────────────────────────────────────────────

function! ghostgit#command#Open(cmd, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let arg = a:arg
  if empty(arg)
    let arg = ghostgit#buffer#Relative()
  endif
  let file = ghostgit#buffer#Find(arg, dir)
  if empty(file)
    return 'echoerr ' . string('ghostgit: could not resolve ' . arg)
  endif
  let mods = ghostgit#util#Mods(a:mods)
  return mods . a:cmd . (a:bang ? '!' : '') . ' ' . ghostgit#util#FnameEscape(file)
endfunction

" ── Drop command ────────────────────────────────────────────────────

function! ghostgit#command#DropCommand(line1, count, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let arg = a:arg
  if empty(arg)
    let arg = ghostgit#buffer#Relative()
  endif
  let file = ghostgit#buffer#Find(arg, dir)
  if empty(file)
    return 'echoerr ' . string('ghostgit: could not resolve ' . arg)
  endif
  let mods = ghostgit#util#Mods(a:mods)
  return mods . 'drop ' . ghostgit#util#FnameEscape(file)
endfunction

" ── Read command ────────────────────────────────────────────────────

function! ghostgit#command#ReadCommand(line1, count, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let arg = a:arg
  if empty(arg)
    let arg = '@:'
  endif
  let file = ghostgit#buffer#Find(arg, dir)
  if empty(file)
    return 'echoerr ' . string('ghostgit: could not resolve ' . arg)
  endif
  let mods = ghostgit#util#Mods(a:mods)
  return mods . (a:line1 > 0 ? a:line1 : '') . 'read ' . ghostgit#util#FnameEscape(file)
endfunction

" ── Write command ───────────────────────────────────────────────────

function! ghostgit#command#WriteCommand(line1, line2, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  exe ghostgit#core#DirCheck(dir)
  let arg = a:arg
  if empty(arg)
    let arg = ':0:'
  endif
  let file = ghostgit#buffer#Find(arg, dir)
  if empty(file)
    return 'echoerr ' . string('ghostgit: could not resolve ' . arg)
  endif
  " Write to index
  let r = ghostgit#git#Execute([dir, 'hash-object', '-w', '--stdin', '--', expand('%:p')], {'stdin': getline(1, '$')})
  if r.exit_status
    return 'echoerr ' . string('ghostgit: ' . join(r.stderr, "\n"))
  endif
  let sha = r.stdout[0]
  let fperm = getfperm(expand('%:p'))
  let mode = fperm =~# 'x' ? '100755' : '100644'
  let r = ghostgit#git#Execute([dir, 'update-index', '--cacheinfo', mode, sha, expand('%:p')])
  if r.exit_status
    return 'echoerr ' . string('ghostgit: ' . join(r.stderr, "\n"))
  endif
  call ghostgit#status#DidChange(dir)
  return ''
endfunction

" ── Wq command ──────────────────────────────────────────────────────

function! ghostgit#command#WqCommand(...) abort
  let result = call('ghostgit#command#WriteCommand', a:000)
  if empty(result)
    return 'quit'
  endif
  return result
endfunction

" ── Move/Rename/Remove/Delete/Unlink ────────────────────────────────

function! ghostgit#command#MoveCommand(line1, line2, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let args = split(a:arg, '\s\+')
  if len(args) != 2
    return 'echoerr ' . string('ghostgit: GMove requires source and destination')
  endif
  let r = ghostgit#git#Execute([dir, 'mv', '--'] + args)
  call ghostgit#status#DidChange(r)
  return ''
endfunction

function! ghostgit#command#RenameCommand(line1, line2, range, bang, mods, arg, ...) abort
  return call('ghostgit#command#MoveCommand', a:000)
endfunction

function! ghostgit#command#RemoveCommand(line1, line2, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let r = ghostgit#git#Execute([dir, 'rm', '--', expand('%:p')])
  call ghostgit#status#DidChange(r)
  return ''
endfunction

function! ghostgit#command#UnlinkCommand(line1, line2, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  call delete(expand('%:p'))
  call ghostgit#status#DidChange(ghostgit#core#GitDir())
  return ''
endfunction

function! ghostgit#command#DeleteCommand(line1, line2, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let r = ghostgit#git#Execute([dir, 'rm', '--cached', '--', expand('%:p')])
  call ghostgit#status#DidChange(r)
  return ''
endfunction

" ── Grep command ────────────────────────────────────────────────────

function! ghostgit#command#GrepCommand(line1, line2, range, bang, mods, arg) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let args = split(a:arg, '\s\+')
  let cmd = [dir, 'grep', '--line-number'] + args
  let r = ghostgit#git#Execute(cmd)
  if empty(r.stdout)
    return 'echo ' . string('No matches found')
  endif
  " Populate quickfix
  let qf = []
  for line in r.stdout
    let m = matchlist(line, '^\(.\{-}\):\(\d\+\):\(.*\)')
    if len(m) >= 4
      call add(qf, {'filename': m[1], 'lnum': +m[2], 'text': m[3]})
    endif
  endfor
  call setqflist(qf)
  return 'copen'
endfunction

" ── Log command ─────────────────────────────────────────────────────

function! ghostgit#command#LogCommand(line1, count, range, bang, mods, args, type) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  let args = split(a:args, '\s\+')
  let cmd = [dir, 'log', '--no-pager'] + args
  let r = ghostgit#git#Execute(cmd)
  if empty(r.stdout)
    return 'echo ' . string('No commits found')
  endif
  " Populate location or quickfix list
  let qf = []
  for line in r.stdout
    if line =~# '^[a-f0-9]\{40,\}'
      call add(qf, {'text': line})
    endif
  endfor
  if a:type ==# 'l'
    call setloclist(0, qf)
    return 'lopen'
  else
    call setqflist(qf)
    return 'copen'
  endif
endfunction

" ── Commit/Revert/Merge/Rebase/Pull/Push/Fetch/Blame/Bisect ─────────

function! ghostgit#command#Commit(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Revert(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Merge(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Rebase(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Pull(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Push(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Fetch(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Blame(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Bisect(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Difftool(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

function! ghostgit#command#Mergetool(line1, line2, range, bang, mods, args) abort
  return ghostgit#command#Run(a:line1, a:line2, a:range, a:bang, a:mods, a:args)
endfunction

" ── Cd command ──────────────────────────────────────────────────────

function! ghostgit#command#Cd(path, ...) abort
  let dir = ghostgit#core#GitDir()
  if empty(dir)
    return 'echoerr ' . string('ghostgit: not a git repository')
  endif
  let tree = ghostgit#core#GetTree(dir)
  if empty(tree)
    return 'echoerr ' . string('ghostgit: no work tree')
  endif
  let target = tree . (empty(a:path) ? '' : '/' . a:path)
  if !isdirectory(target)
    return 'echoerr ' . string('ghostgit: ' . target . ' is not a directory')
  endif
  if a:0 && a:1
    exe 'lcd ' . ghostgit#util#FnameEscape(target)
  else
    exe 'cd ' . ghostgit#util#FnameEscape(target)
  endif
  return ''
endfunction

" ── Completion ──────────────────────────────────────────────────────

function! ghostgit#command#Complete(lead, ...) abort
  let lead = a:lead
  if lead =~# '^-'
    return filter(['--git-dir=', '--work-tree=', '--help', '--version', '-c', '-C'], 'stridx(v:val, lead) == 0')
  endif
  let subcommands = ['status', 'commit', 'revert', 'merge', 'rebase', 'pull', 'push', 'fetch', 'blame', 'log', 'grep', 'diff', 'show', 'branch', 'checkout', 'reset', 'rm', 'mv', 'bisect', 'difftool', 'mergetool']
  if empty(lead)
    return subcommands
  endif
  return filter(subcommands, 'stridx(v:val, lead) == 0')
endfunction

function! ghostgit#command#CompletePath(base, ...) abort
  let dir = ghostgit#core#GitDir()
  let tree = ghostgit#core#GetTree(dir)
  if empty(tree)
    return []
  endif
  let base = a:base
  if base =~# '^/'
    return split(glob(base . '*'), "\n")
  endif
  return split(glob(tree . '/' . base . '*'), "\n")
endfunction

function! ghostgit#command#CdComplete(A, L, P) abort
  let dir = ghostgit#core#GitDir()
  let tree = ghostgit#core#GetTree(dir)
  if empty(tree)
    return []
  endif
  return split(glob(tree . '/' . a:A . '*'), "\n")
endfunction

function! ghostgit#command#CompleteForWorkingDir(A, L, P, ...) abort
  return ghostgit#command#Complete(a:A)
endfunction

" ── Specific completers ─────────────────────────────────────────────

function! ghostgit#command#CommitComplete(A, L, P, ...) abort
  return ghostgit#command#CompletePath(a:A)
endfunction

function! ghostgit#command#RevertComplete(A, L, P, ...) abort
  return filter(['HEAD', 'HEAD~1', 'HEAD~2'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#MergeComplete(A, L, P, ...) abort
  return filter(['main', 'master', 'develop'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#RebaseComplete(A, L, P, ...) abort
  return filter(['main', 'master', 'develop', 'HEAD'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#PullComplete(A, L, P, ...) abort
  return filter(['origin', 'upstream'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#PushComplete(A, L, P, ...) abort
  return filter(['origin', 'upstream'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#FetchComplete(A, L, P, ...) abort
  return filter(['origin', 'upstream', '--all'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#BisectComplete(A, L, P, ...) abort
  return filter(['start', 'good', 'bad', 'skip', 'reset'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#GrepComplete(A, L, P) abort
  return []
endfunction

function! ghostgit#command#LogComplete(A, L, P) abort
  return filter(['--oneline', '--graph', '--all', '--decorate'], 'stridx(v:val, a:A) == 0')
endfunction

function! ghostgit#command#EditComplete(A, L, P) abort
  return ghostgit#command#CompletePath(a:A)
endfunction

function! ghostgit#command#ReadComplete(A, L, P) abort
  return ghostgit#command#CompletePath(a:A)
endfunction

function! ghostgit#command#RenameComplete(A, L, P) abort
  return ghostgit#command#CompletePath(a:A)
endfunction
