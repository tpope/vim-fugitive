" autoload/ghostgit/remote.vim — Remote parsing, GitHub/GitLab URL, HTTP headers
" Migrated from autoload/fugitive.vim (lines 1304–1506)

" ── URL parsing ─────────────────────────────────────────────────────

function! ghostgit#remote#UrlParse(url) abort
  let scp_authority = matchstr(a:url, '^[^:/]\+\ze:\%(//\)\@!')
  if len(scp_authority) && !(has('win32') && scp_authority =~# '^\a:[\/]')
    let url = {'scheme': 'ssh', 'authority': ghostgit#util#UrlEncode(scp_authority), 'hash': '',
          \ 'path': ghostgit#util#UrlEncode(strpart(a:url, len(scp_authority) + 1))}
  elseif empty(a:url)
    let url = {'scheme': '', 'authority': '', 'path': '', 'hash': ''}
  else
    let match = matchlist(a:url, '^\([[:alnum:].+-]\+\)://\([^/]*\)\(/[^#]*\)\=\(#.*\)\=$')
    if empty(match)
      let url = {'scheme': 'file', 'authority': '', 'hash': '',
            \ 'path': ghostgit#util#UrlEncode(a:url)}
    else
      let url = {'scheme': match[1], 'authority': match[2], 'hash': match[4]}
      let url.path = empty(match[3]) ? '/' : match[3]
    endif
  endif
  return url
endfunction

function! ghostgit#remote#UrlPopulate(string, into) abort
  let url = a:into
  let url.protocol = substitute(url.scheme, '.\zs$', ':', '')
  let url.user = ghostgit#util#UrlDecode(matchstr(url.authority, '.\{-\}\ze@', '', ''))
  let url.host = substitute(url.authority, '.\{-\}@', '', '')
  let url.hostname = substitute(url.host, ':\d\+$', '', '')
  let url.port = matchstr(url.host, ':\zs\d\+$', '', '')
  let url.origin = substitute(url.scheme, '.\zs$', '://', '') . url.host
  let url.search = matchstr(url.path, '?.*')
  let url.pathname = '/' . matchstr(url.path, '^/\=\zs[^?]*')
  if (url.scheme ==# 'ssh' || url.scheme ==# 'git') && url.path[0:1] ==# '/~'
    let url.path = strpart(url.path, 1)
  endif
  if url.path =~# '^/'
    let url.href = url.scheme . '://' . url.authority . url.path . url.hash
  elseif url.path =~# '^\~'
    let url.href = url.scheme . '://' . url.authority . '/' . url.path . url.hash
  elseif url.scheme ==# 'ssh' && url.authority !~# ':'
    let url.href = url.authority . ':' . url.path . url.hash
  else
    let url.href = a:string
  endif
  let url.path = ghostgit#util#UrlDecode(matchstr(url.path, '^[^?]*'))
  let url.url = matchstr(url.href, '^[^#]*')
endfunction

" ── Remote resolve ──────────────────────────────────────────────────

function! ghostgit#remote#RemoteResolve(url, flags) abort
  let remote = ghostgit#remote#UrlParse(a:url)
  if remote.scheme =~# '^https\=$' && index(a:flags, ':nohttp') < 0
    let headers = ghostgit#remote#HttpHeaders(a:url)
    let loc = matchstr(get(headers, 'location', ''), '^https\=://.\{-\}\ze/info/refs?')
    if len(loc)
      let remote = ghostgit#remote#UrlParse(loc)
    else
      let remote.headers = headers
    endif
  elseif remote.scheme ==# 'ssh'
    let remote.authority = ghostgit#config#SshHostAlias(remote.authority)
  endif
  return remote
endfunction

" ── Remote callback ─────────────────────────────────────────────────

function! s:config_length_sort(i1, i2) abort
  return len(a:i2[0]) - len(a:i1[0])
endfunction

function! ghostgit#remote#RemoteCallback(config, into, flags, cb) abort
  if a:into.remote_name =~# '^\.\=$'
    let a:into.remote_name = ghostgit#config#RemoteDefault(a:config)
  endif
  let url = a:into.remote_name

  if url ==# '.git'
    let url = ghostgit#core#GitDir(a:config)
  elseif url !~# ':\|^/\|^\a:[\/]\|^\.\.\=/'
    let url = ghostgit#config#Get('remote.' . url . '.url', a:config)
  endif
  let instead_of = []
  for [k, vs] in items(ghostgit#config#GetRegexp('^url\.\zs.\{-\}\ze\.insteadof$', a:config))
    for v in vs
      call add(instead_of, [v, k])
    endfor
  endfor
  call sort(instead_of, 's:config_length_sort')
  for [orig, replacement] in instead_of
    if strpart(url, 0, len(orig)) ==# orig
      let url = replacement . strpart(url, len(orig))
      break
    endif
  endfor
  if index(a:flags, ':noresolve') < 0
    call extend(a:into, ghostgit#remote#RemoteResolve(url, a:flags))
  else
    call extend(a:into, ghostgit#remote#UrlParse(url))
  endif
  call ghostgit#remote#UrlPopulate(url, a:into)
  if len(a:cb)
    call call(a:cb[0], [a:into] + a:cb[1:-1])
  endif
endfunction

" ── Remote factory ──────────────────────────────────────────────────

function! ghostgit#remote#Remote(dir, remote, flags, cb) abort
  let into = {'remote_name': a:remote, 'git_dir': ghostgit#core#GitDir(a:dir)}
  let config = ghostgit#config#Config(a:dir, function('ghostgit#remote#RemoteCallback'), into, a:flags, a:cb)
  if len(a:cb)
    return config
  else
    call ghostgit#job#Wait(config)
    return into
  endif
endfunction

" ── Remote parse args ───────────────────────────────────────────────

function! ghostgit#remote#ParseArgs(args) abort
  let args = []
  let flags = []
  let cb = copy(a:args)
  while len(cb)
    if type(cb[0]) ==# type(function('tr'))
      break
    elseif len(args) > 1 || type(cb[0]) ==# type('') && cb[0] =~# '^:'
      call add(flags, remove(cb, 0))
    else
      call add(args, remove(cb, 0))
    endif
  endwhile

  let remote = ''
  if empty(args)
    let dir_or_config = ghostgit#core#GitDir()
  elseif len(args) == 1 && type(args[0]) ==# type('') && args[0] !~# '^/\|^\a:[\\/]'
    let dir_or_config = ghostgit#core#GitDir()
    let remote = args[0]
  elseif len(args) == 1
    let dir_or_config = args[0]
    if type(args[0]) ==# type({}) && has_key(args[0], 'remote_name')
      let remote = args[0].remote_name
    endif
  elseif type(args[1]) !=# type('') || args[1] =~# '^/\|^\a:[\\/]'
    let dir_or_config = args[1]
    let remote = args[0]
  else
    let dir_or_config = args[0]
    let remote = args[1]
  endif
  return [dir_or_config, remote, flags, cb]
endfunction

" ── Public API ──────────────────────────────────────────────────────

function! ghostgit#remote#Remote(...) abort
  let [dir_or_config, remote, flags, cb] = ghostgit#remote#ParseArgs(a:000)
  return ghostgit#remote#Remote(dir_or_config, remote, flags, cb)
endfunction

function! ghostgit#remote#RemoteUrl(...) abort
  let remote = call('ghostgit#remote#Remote', a:000)
  call ghostgit#job#Wait(remote)
  return get(remote, 'url', '')
endfunction

" ── HTTP headers ────────────────────────────────────────────────────

function! s:curl_response(result) abort
  let a:result.headers = {}
  for line in a:result.exit_status ? [] : remove(a:result, 'stdout')
    let header = matchlist(line, '^\([[:alnum:]-]\+\):\s\(.\{-\}\)' . "\r\\=$")
    if len(header)
      let k = tolower(header[1])
      if has_key(a:result.headers, k)
        let a:result.headers[k] .= ', ' . header[2]
      else
        let a:result.headers[k] = header[2]
      endif
    elseif empty(line)
      break
    endif
  endfor
endfunction

function! ghostgit#remote#HttpHeaders(remote) abort
  let remote_headers = ghostgit#state#GetRemoteHeaders()
  let remote = type(a:remote) ==# type({}) ? get(a:remote, 'remote', '') : a:remote
  if type(remote) !=# type('') || remote !~# '^https\=://.' || !ghostgit#util#IsExecutable('curl')
    return {}
  endif
  let remote = substitute(remote, '#.*', '', '')
  if !has_key(remote_headers, remote)
    let url = remote . '/info/refs?service=git-upload-pack'
    let exec = ghostgit#job#JobExecute(
          \ ['curl', '--disable', '--silent', '--max-time', '5', '-X', 'GET', '-I',
          \ url], {}, [], [function('s:curl_response')], {})
    call ghostgit#job#Wait(exec)
    let remote_headers[remote] = exec.headers
  endif
  return remote_headers[remote]
endfunction
