" autoload/ghostgit/util.vim — Pure helpers, string/path utilities
" Migrated from autoload/fugitive.vim Section: Utility (lines 9–317)

" ── Function reference ──────────────────────────────────────────────

function! ghostgit#util#Function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

" ── String helpers ──────────────────────────────────────────────────

function! ghostgit#util#Sub(str, pat, rep) abort
  return substitute(a:str, '\v\C' . a:pat, a:rep, '')
endfunction

function! ghostgit#util#Gsub(str, pat, rep) abort
  return substitute(a:str, '\v\C' . a:pat, a:rep, 'g')
endfunction

function! ghostgit#util#Uniq(list) abort
  let i = 0
  let seen = {}
  while i < len(a:list)
    let str = string(a:list[i])
    if has_key(seen, str)
      call remove(a:list, i)
    else
      let seen[str] = 1
      let i += 1
    endif
  endwhile
  return a:list
endfunction

function! ghostgit#util#JoinChomp(list) abort
  if empty(a:list[-1])
    return join(a:list[0:-2], "\n")
  else
    return join(a:list, "\n")
  endif
endfunction

" ── Shell escaping ──────────────────────────────────────────────────

function! s:winshell() abort
  return has('win32') && &shellcmdflag !~# '^-'
endfunction

function! ghostgit#util#WinShellEsc(arg) abort
  if type(a:arg) == type([])
    return join(map(copy(a:arg), 'ghostgit#util#WinShellEsc(v:val)'))
  elseif a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  else
    return '"' . ghostgit#util#Gsub(ghostgit#util#Gsub(a:arg, '"', '""'), '\%', '"%"') . '"'
  endif
endfunction

function! ghostgit#util#ShellEsc(arg) abort
  if type(a:arg) == type([])
    return join(map(copy(a:arg), 'ghostgit#util#ShellEsc(v:val)'))
  elseif a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  elseif s:winshell()
    return '"' . ghostgit#util#Gsub(ghostgit#util#Gsub(a:arg, '"', '""'), '\%', '"%"') . '"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! ghostgit#util#FnameEscape(file) abort
  if type(a:file) == type([])
    return join(map(copy(a:file), 'ghostgit#util#FnameEscape(v:val)'))
  else
    return fnameescape(a:file)
  endif
endfunction

" ── URL encoding ────────────────────────────────────────────────────

function! ghostgit#util#UrlDecode(str) abort
  return substitute(a:str, '%\(\x\x\)', '\=iconv(nr2char("0x".submatch(1)), "utf-8", "latin1")', 'g')
endfunction

function! ghostgit#util#UrlEncode(str) abort
  return substitute(a:str, '[%#?&;+=\<> [:cntrl:]]', '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! ghostgit#util#PathUrlEncode(str) abort
  return substitute(a:str, '[%#?[:cntrl:]]', '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! ghostgit#util#PathJoin(prefix, str) abort
  if a:prefix =~# '://'
    return a:prefix . ghostgit#util#PathUrlEncode(a:str)
  else
    return a:prefix . a:str
  endif
endfunction

" ── Error throwing ──────────────────────────────────────────────────

function! ghostgit#util#Throw(string) abort
  throw 'ghostgit: ' . a:string
endfunction

" ── Path normalization ──────────────────────────────────────────────

if exists('+shellslash')

  function! ghostgit#util#Slash(path) abort
    return tr(a:path, '\', '/')
  endfunction

  function! ghostgit#util#VimSlash(path) abort
    return tr(a:path, '\/', &shellslash ? '//' : '\\')
  endfunction

else

  function! ghostgit#util#Slash(path) abort
    return a:path
  endfunction

  function! ghostgit#util#VimSlash(path) abort
    return a:path
  endfunction

endif

" ── Vim path (reverse of VimSlash) ──────────────────────────────────

if exists('+shellslash')

  function! ghostgit#util#VimPath(path) abort
    return tr(a:path, '\/', &shellslash ? '//' : '\\')
  endfunction

else

  if has('win32unix') && filereadable('/git-bash.exe')
    function! ghostgit#util#VimPath(path) abort
      return substitute(a:path, '^\(\a\):', '/\l\1', '')
    endfunction
  else
    function! ghostgit#util#VimPath(path) abort
      return a:path
    endfunction
  endif

endif

" ── Absolute path ───────────────────────────────────────────────────

function! ghostgit#util#AbsoluteVimPath(...) abort
  if a:0 && type(a:1) == type('')
    let path = a:1
  else
    let path = bufname(a:0 && a:1 > 0 ? a:1 : '')
    if getbufvar(a:0 && a:1 > 0 ? a:1 : '', '&buftype') !~# '^\%(nowrite\|acwrite\)\=$'
      return path
    endif
  endif
  if ghostgit#util#Slash(path) =~# '^/\|^\a\+:'
    return path
  else
    return getcwd() . matchstr(getcwd(), '[\\/]') . path
  endif
endfunction

" ── Resolve symlinks ────────────────────────────────────────────────

function! ghostgit#util#Resolve(path) abort
  let path = resolve(a:path)
  if has('win32')
    let path = ghostgit#util#VimSlash(fnamemodify(fnamemodify(path, ':h'), ':p') . fnamemodify(path, ':t'))
  endif
  return path
endfunction

" ── Case-insensitive file check ─────────────────────────────────────

function! ghostgit#util#FileIgnoreCase(for_completion) abort
  return (exists('+fileignorecase') && &fileignorecase)
        \ || (a:for_completion && exists('+wildignorecase') && &wildignorecase)
endfunction

" ── Case-insensitive path comparison ────────────────────────────────

function! ghostgit#util#Cpath(path, ...) abort
  if ghostgit#util#FileIgnoreCase(0)
    let path = ghostgit#util#VimSlash(tolower(a:path))
  else
    let path = ghostgit#util#VimSlash(a:path)
  endif
  return a:0 ? path ==# ghostgit#util#Cpath(a:1) : path
endfunction

" ── Quote / Unquote (Git config format) ─────────────────────────────

let s:quote_chars = {
      \ "\007": 'a', "\010": 'b', "\011": 't', "\012": 'n', "\013": 'v', "\014": 'f', "\015": 'r',
      \ '"': '"', '\': '\'}

let s:unquote_chars = {
      \ 'a': "\007", 'b': "\010", 't': "\011", 'n': "\012", 'v': "\013", 'f': "\014", 'r': "\015",
      \ '"': '"', '\': '\'}

function! ghostgit#util#Quote(string) abort
  let string = substitute(a:string, "[\001-\037\"\\\177]", '\="\\" . get(s:quote_chars, submatch(0), printf("%03o", char2nr(submatch(0))))', 'g')
  if string !=# a:string
    return '"' . string . '"'
  else
    return string
  endif
endfunction

function! ghostgit#util#Unquote(string) abort
  let string = substitute(a:string, "\t*$", '', '')
  if string =~# '^".*"$'
    return substitute(string[1:-2], '\\\(\o\o\o\|.\)', '\=get(s:unquote_chars, submatch(1), iconv(nr2char("0" . submatch(1)), "utf-8", "latin1"))', 'g')
  else
    return string
  endif
endfunction

" ── Executable cache ────────────────────────────────────────────────

let s:executables = {}

function! ghostgit#util#IsExecutable(binary) abort
  if !has_key(s:executables, a:binary)
    let s:executables[a:binary] = executable(a:binary)
  endif
  return s:executables[a:binary]
endfunction

" ── Temp script helper ──────────────────────────────────────────────

let s:temp_scripts = {}

function! ghostgit#util#TempScript(...) abort
  let body = join(a:000, "\n")
  if !has_key(s:temp_scripts, body)
    let s:temp_scripts[body] = tempname() . '.sh'
  endif
  let temp = s:temp_scripts[body]
  if !filereadable(temp)
    call writefile(['#!/bin/sh'] + a:000, temp)
  endif
  let temp = ghostgit#util#Slash(temp)
  if temp =~# '\s'
    let temp = '"' . temp . '"'
  endif
  return temp
endfunction

" ── Autocmd helper ──────────────────────────────────────────────────

function! ghostgit#util#DoAutocmd(...) abort
  return join(map(copy(a:000), "'doautocmd <nomodeline>' . v:val"), '|')
endfunction

" ── Map helper ──────────────────────────────────────────────────────

function! ghostgit#util#Map(mode, lhs, rhs, ...) abort
  let maps = []
  let flags = a:0 && type(a:1) == type('') ? a:1 : ''
  let defer = flags =~# '<unique>'
  let flags = substitute(flags, '<unique>', '', '') . (a:rhs =~# '<Plug>' ? '' : '<script>') . '<nowait>'
  for mode in split(a:mode, '\zs')
    if a:0 <= 1
      call add(maps, mode.'map <buffer>' . substitute(flags, '<unique>', '', '') . ' <Plug>ghostgit:' . a:lhs . ' ' . a:rhs)
    endif
    let skip = 0
    let head = a:lhs
    let tail = ''
    let keys = get(g:, mode.'remap', {})
    if type(keys) == type([])
      continue
    endif
    while !empty(head)
      if has_key(keys, head)
        let head = keys[head]
        if empty(head)
          let skip = 1
          break
        endif
        break
      endif
      let tail = matchstr(head, '<[^<>]*>$\|.$') . tail
      let head = substitute(head, '<[^<>]*>$\|.$', '', '')
    endwhile
    if skip | continue | endif
    if empty(head) || !defer || empty(mapcheck(head . tail, mode))
      call add(maps, mode.'map <buffer>' . flags . ' ' . head . tail . ' ' . a:rhs)
    endif
  endfor
  return join(maps, '|')
endfunction

" ── Window modifier normalization ───────────────────────────────────
" Note: 'SpanOrigin' default requires state.vim to be loaded;
" the full implementation with OriginBufnr lives in ghostgit#state#Mods.

function! ghostgit#util#Mods(mods, ...) abort
  let mods = substitute(a:mods, '\C<mods>', '', '')
  let mods = mods =~# '\S$' ? mods . ' ' : mods
  if a:0 && mods !~# '\<\d*\%(aboveleft\|belowright\|leftabove\|rightbelow\|topleft\|botright\|tab\)\>'
    let default = a:1
    if default ==# 'SpanOrigin' || default ==# 'Edge'
      if mods =~# '\<vertical\>' ? &splitright : &splitbelow
        let mods = 'botright ' . mods
      else
        let mods = 'topleft ' . mods
      endif
    else
      let mods = default . ' ' . mods
    endif
  endif
  return substitute(mods, '\s\+', ' ', 'g')
endfunction

" ── Autowrite ───────────────────────────────────────────────────────

function! ghostgit#util#Autowrite() abort
  if &autowriteall || (&autowrite && (!&modified || &buftype ==# ''))
    try
      if &autowriteall
        silent! wall
      elseif &autowrite
        silent! write
      endif
    catch
    endtry
  endif
  return ''
endfunction

" ── Cfile handling (was fugitive#MapCfile) ──────────────────────────

function! ghostgit#util#MapCfile(...) abort
  let candidates = s:cfile()
  for candidate in candidates
    let file = ghostgit#buffer#Find(candidate)
    if !empty(file)
      return (a:0 ? a:1 : 'edit') . ' ' . ghostgit#util#FnameEscape(file)
    endif
  endfor
  return ''
endfunction

function! ghostgit#util#PorcelainMapCfile(...) abort
  let candidates = s:CfilePorcelain()
  if empty(candidates)
    return ghostgit#util#MapCfile(a:0 ? a:1 : 'edit')
  endif
  for candidate in candidates
    let file = ghostgit#buffer#Find(candidate)
    if !empty(file)
      return (a:0 ? a:1 : 'edit') . ' ' . ghostgit#util#FnameEscape(file)
    endif
  endfor
  return ''
endfunction

function! s:cfile() abort
  if empty(ghostgit#core#GitDir())
    return []
  endif
  let line = getline('.')
  let candidates = []

  " commit hash
  let hash = matchstr(line, '\<[0-9a-f]\{7,40\}\>')
  if !empty(hash)
    call add(candidates, hash)
  endif

  " file path in ls-tree or similar
  let path = matchstr(line, '\t\zs.*')
  if !empty(path)
    call add(candidates, path)
  endif

  return candidates
endfunction

function! s:CfilePorcelain() abort
  let line = getline('.')
  if line =~# '^[A-Z?] '
    return [line[2:-1]]
  endif
  return []
endfunction
