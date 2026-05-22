" autoload/ghostgit/config.vim — Git config, SSH config, plugin config
" Migrated from autoload/fugitive.vim Section: Git config (lines 1050–1302)

" ── Config prototype methods ────────────────────────────────────────

function! ghostgit#config#GetAll(name, ...) abort
  if a:0 && (type(a:name) !=# type('') || a:name !~# '^[[:alnum:]-]\+\.' && type(a:1) ==# type('') && a:1 =~# '^[[:alnum:]-]\+\.')
    let config = ghostgit#config#Config(a:name)
    let name = a:1
  else
    let config = ghostgit#config#Config(a:0 ? a:1 : ghostgit#core#GitDir())
    let name = a:name
  endif
  let name = substitute(name, '^[^.]\+\|[^.]\+$', '\L&', 'g')
  call ghostgit#job#Wait(config)
  return name =~# '\.' ? copy(get(config, name, [])) : []
endfunction

function! ghostgit#config#Get(name, ...) abort
  return get(call('ghostgit#config#GetAll', [a:name] + (a:0 ? [a:1] : [])), -1, get(a:, 2, ''))
endfunction

function! ghostgit#config#GetRegexp(pattern, ...) abort
  if type(a:pattern) !=# type('')
    let config = a:pattern
    let pattern = a:0 ? a:1 : '.*'
  else
    let config = ghostgit#config#Config(a:0 ? a:1 : ghostgit#core#GitDir())
    let pattern = a:pattern
  endif
  call ghostgit#job#Wait(config)
  let filtered = map(filter(copy(config), 'v:key =~# "\\." && v:key =~# pattern'), 'copy(v:val)')
  if pattern !~# '\\\@<!\%(\\\\\)*\\z[se]'
    return filtered
  endif
  let transformed = {}
  for [k, v] in items(filtered)
    let k = matchstr(k, pattern)
    if len(k)
      let transformed[k] = v
    endif
  endfor
  return transformed
endfunction

" ── Config object ───────────────────────────────────────────────────

function! s:config_GetAll(name) dict abort
  let name = substitute(a:name, '^[^.]\+\|[^.]\+$', '\L&', 'g')
  call ghostgit#job#Wait(self)
  return name =~# '\.' ? copy(get(self, name, [])) : []
endfunction

function! s:config_Get(name, ...) dict abort
  return get(self.GetAll(a:name), -1, a:0 ? a:1 : '')
endfunction

function! s:config_GetRegexp(pattern) dict abort
  return ghostgit#config#GetRegexp(self, a:pattern)
endfunction

let s:config_prototype = {
      \ 'GetAll': function('s:config_GetAll'),
      \ 'Get': function('s:config_Get'),
      \ 'GetRegexp': function('s:config_GetRegexp')}

" ── Config timestamps ───────────────────────────────────────────────

function! s:config_timestamps(dir, dict) abort
  let files = ['/etc/gitconfig', '~/.gitconfig',
        \ len($XDG_CONFIG_HOME) ? $XDG_CONFIG_HOME . '/git/config' : '~/.config/git/config']
  if len(a:dir)
    call add(files, ghostgit#buffer#Find('.git/config', a:dir))
  endif
  call extend(files, get(a:dict, 'include.path', []))
  return join(map(files, 'getftime(expand(v:val))'), ',')
endfunction

" ── Config callback ─────────────────────────────────────────────────

function! s:config_callback(r, into) abort
  let dict = a:into[1]
  if has_key(dict, 'job')
    call remove(dict, 'job')
  endif
  let lines = a:r.exit_status ? [] : split(tr(join(a:r.stdout, "\1"), "\1\n", "\n\1"), "\1", 1)[0:-2]
  for line in lines
    let key = matchstr(line, "^[^\n]*")
    if !has_key(dict, key)
      let dict[key] = []
    endif
    if len(key) ==# len(line)
      call add(dict[key], 1)
    else
      call add(dict[key], strpart(line, len(key) + 1))
    endif
  endfor
  let callbacks = remove(dict, 'callbacks')
  lockvar! dict
  let a:into[0] = s:config_timestamps(dict.git_dir, dict)
  for callback in callbacks
    call call(callback[0], [dict] + callback[1:-1])
  endfor
endfunction

" ── Expire config ───────────────────────────────────────────────────

function! ghostgit#config#Expire(...) abort
  call ghostgit#state#ClearConfigCache(a:0 ? (a:1 is# '' ? '_' : a:1) : '')
endfunction

" ── Config factory ──────────────────────────────────────────────────

function! ghostgit#config#Config(...) abort
  let name = ''
  let default = get(a:, 3, '')
  if a:0 && type(a:1) == type(function('tr'))
    let dir = ghostgit#core#GitDir()
    let callback = a:000
  elseif a:0 > 1 && type(a:2) == type(function('tr'))
    if type(a:1) == type({}) && has_key(a:1, 'GetAll')
      if has_key(a:1, 'callbacks')
        call add(a:1.callbacks, a:000[1:-1])
      else
        call call(a:2, [a:1] + a:000[2:-1])
      endif
      return a:1
    else
      let dir = ghostgit#core#GitDir(a:1)
      let callback = a:000[1:-1]
    endif
  elseif a:0 >= 2 && type(a:2) == type({}) && has_key(a:2, 'GetAll')
    return get(ghostgit#config#GetAll(a:1, a:2), -1, default)
  elseif a:0 >= 2
    let dir = ghostgit#core#GitDir(a:2)
    let name = a:1
  elseif a:0 == 1 && type(a:1) == type({}) && has_key(a:1, 'GetAll')
    return a:1
  elseif a:0 == 1 && type(a:1) == type('') && a:1 =~# '^[[:alnum:]-]\+\.'
    let dir = ghostgit#core#GitDir()
    let name = a:1
  elseif a:0 == 1
    let dir = ghostgit#core#GitDir(a:1)
  else
    let dir = ghostgit#core#GitDir()
  endif
  let name = substitute(name, '^[^.]\+\|[^.]\+$', '\L&', 'g')
  let git_dir = ghostgit#core#GitDir(dir)
  let dir_key = len(git_dir) ? git_dir : '_'
  let config_cache = ghostgit#state#GetConfigCache()
  let [ts, dict] = get(config_cache, dir_key, ['new', {}])
  if !has_key(dict, 'job') && ts !=# s:config_timestamps(git_dir, dict)
    let dict = copy(s:config_prototype)
    let dict.git_dir = git_dir
    let into = ['running', dict]
    let dict.callbacks = []
    let exec = ghostgit#git#Execute([dir, 'config', '--list', '-z', '--'], function('s:config_callback'), into)
    if has_key(exec, 'job')
      let dict.job = exec.job
    endif
    let config_cache[dir_key] = into
  endif
  if !exists('l:callback')
    call ghostgit#job#Wait(dict)
  elseif has_key(dict, 'callbacks')
    call add(dict.callbacks, callback)
  else
    call call(callback[0], [dict] + callback[1:-1])
  endif
  return len(name) ? get(ghostgit#config#GetAll(name, dict), 0, default) : dict
endfunction

" ── Remote default ──────────────────────────────────────────────────

function! ghostgit#config#RemoteDefault(dir) abort
  let head = ghostgit#git#Head(0, a:dir)
  let remote = len(head) ? ghostgit#config#Get('branch.' . head . '.remote', a:dir) : ''
  let i = 10
  while remote ==# '.' && i > 0
    let head = matchstr(ghostgit#config#Get('branch.' . head . '.merge', a:dir), 'refs/heads/\zs.*')
    let remote = len(head) ? ghostgit#config#Get('branch.' . head . '.remote', a:dir) : ''
    let i -= 1
  endwhile
  return remote =~# '^\.\=$' ? 'origin' : remote
endfunction

" ── SSH config parsing ──────────────────────────────────────────────

function! ghostgit#config#SshParseHost(value) abort
  let patterns = []
  let negates = []
  for host in split(a:value, '\s\+')
    let pattern = substitute(host, '[\\^$.*~?]', '\=submatch(0) == "*" ? ".*" : submatch(0) == "?" ? "." : "\\" . submatch(0)', 'g')
    if pattern[0] ==# '!'
      call add(negates, '\&\%(^' . pattern[1 : -1] . '$\)\@!')
    else
      call add(patterns, pattern)
    endif
  endfor
  return '^\%(' . join(patterns, '\|') . '\)$' . join(negates, '')
endfunction

function! ghostgit#config#SshParseConfig(into, root, file) abort
  try
    let lines = readfile(a:file)
  catch
    return a:into
  endtry
  let host = '^\%(.*\)$'
  while !empty(lines)
    let line = remove(lines, 0)
    let key = tolower(matchstr(line, '^\s*\zs\w\+\ze\s'))
    let value = matchstr(line, '^\s*\w\+\s\+\zs.*\S')
    if key ==# 'match'
      let host = value ==# 'all' ? '^\%(.*\)$' : ''
    elseif key ==# 'host'
      let host = ghostgit#config#SshParseHost(value)
    elseif key ==# 'include'
      for glob in split(value)
        if glob !~# '^[~/]'
          let glob = a:root . glob
        endif
        for included in reverse(split(glob(glob), "\n"))
          try
            let lines = readfile(included) + lines
          catch
          endtry
        endfor
      endfor
    elseif len(key) && len(host)
      call extend(a:into, {key : []}, 'keep')
      call add(a:into[key], [host, value])
    endif
  endwhile
  return a:into
endfunction

let s:ssh_config = {}

function! ghostgit#config#SshConfig(host, ...) abort
  if empty(s:ssh_config)
    for file in [expand("~/.ssh/config"), "/etc/ssh/ssh_config"]
      call ghostgit#config#SshParseConfig(s:ssh_config, substitute(file, '\w*$', '', ''), file)
    endfor
  endif
  let host_config = {}
  for key in a:0 ? a:1 : keys(s:ssh_config)
    for [host_pattern, value] in get(s:ssh_config, key, [])
      if a:host =~# host_pattern
        let host_config[key] = value
        break
      endif
    endfor
  endfor
  return host_config
endfunction

function! ghostgit#config#SshHostAlias(authority) abort
  let [_, user, host, port; __] = matchlist(a:authority, '^\%(\([^/@]\+\)@\)\=\(.\{-\}\)\%(:\(\d\+\)\)\=$')
  let c = ghostgit#config#SshConfig(host, ['user', 'hostname', 'port'])
  if empty(user)
    let user = get(c, 'user', '')
  endif
  if empty(port)
    let port = get(c, 'port', '')
  endif
  return (len(user) ? user . '@' : '') . get(c, 'hostname', host) . (port =~# '^\%(22\)\=$' ? '' : ':' . port)
endfunction
