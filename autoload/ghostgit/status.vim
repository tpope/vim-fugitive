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
  exe ghostgit#buffer#BufReadStatus(0)
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
