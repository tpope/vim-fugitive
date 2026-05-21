" autoload/ghostgit/browse.vim — Open browser, remote links, line URLs
" Migrated from autoload/fugitive.vim Section: :GBrowse (lines 7420–7818)

" ── Browser open ────────────────────────────────────────────────────

function! s:browser_open(url, mods, echo_copy) abort
  let [_, main, query, anchor; __] = matchlist(a:url, '^\([^#?]*\)\(?[^#]*\)\=\(#.*\)\=')
  let url = main . tr(query, ' ', '+') . anchor
  let url = substitute(url, '[ <>\|"]', '\="%".printf("%02X",char2nr(submatch(0)))', 'g')
  let mods = ghostgit#util#Mods(a:mods)
  if a:echo_copy
    if has('clipboard')
      let @+ = url
    endif
    return 'echo '.string(url)
  elseif exists(':Browse') == 2
    return 'echo '.string(url).'|' . mods . 'Browse '.url
  elseif exists(':OpenBrowser') == 2
    return 'echo '.string(url).'|' . mods . 'OpenBrowser '.url
  else
    if !exists('g:loaded_netrw')
      runtime! autoload/netrw.vim
      runtime! autoload/netrw/os.vim
    endif
    if exists('*netrw#Open')
      return 'echo '.string(url).'|' . mods . 'call netrw#Open('.string(url).')'
    elseif exists('*netrw#os#Open')
      return 'echo '.string(url).'|' . mods . 'call netrw#os#Open('.string(url).')'
    elseif exists('*netrw#BrowseX')
      return 'echo '.string(url).'|' . mods . 'call netrw#BrowseX('.string(url).', 0)'
    elseif exists('*netrw#NetrwBrowseX')
      return 'echo '.string(url).'|' . mods . 'call netrw#NetrwBrowseX('.string(url).', 0)'
    elseif has('nvim-0.10')
      return mods . 'echo luaeval("({vim.ui.open(_A)})[2] or _A", ' . string(url) . ')'
    else
      return 'echoerr ' . string('Netrw not found. Define your own :Browse to use :GBrowse')
    endif
  endif
endfunction

" ── GBrowse command ─────────────────────────────────────────────────

function! ghostgit#browse#BrowseCommand(line1, count, range, bang, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let dir = ghostgit#core#GitDir()
  try
    let arg = a:arg
    if arg =~# '^++\%([Gg]it\)\=[Rr]emote='
      let remote = matchstr(arg, '^++\%([Gg]it\)\=[Rr]emote=\zs\S\+')
      let arg = matchstr(arg, '\s\zs\S.*')
    endif
    let validremote = '\.\%(git\)\=\|\.\=/.*\|\a[[:alnum:]_-]*\%(://.\{-\}\)\='
    if arg ==# '-'
      let remote = ''
      let rev = ''
      let result = ghostgit#job#Result()
      if filereadable(get(result, 'file', ''))
        let rev = ghostgit#util#FnameEscape(result.file)
      else
        return 'echoerr ' . string('ghostgit: could not find prior :Git invocation')
      endif
    elseif !exists('l:remote')
      let remote = matchstr(arg, '\\\@<!\%(\\\\\)*[!@]\zs\%('.validremote.'\)$')
      let rev = strpart(arg, 0, len(arg) - len(remote) - (empty(remote) ? 0 : 1))
    else
      let rev = arg
    endif
    let expanded = ghostgit#buffer#Expand(rev)
    if expanded =~? '^\a\a\+:[\/][\/]' && expanded !~? '^ghostgit:'
      return s:browser_open(ghostgit#util#Slash(expanded), a:mods, a:bang)
    endif
    if !exists('l:result')
      let result = ghostgit#job#TempState(empty(expanded) ? bufnr('') : expanded)
    endif
    if !get(result, 'origin_bufnr', 1) && filereadable(get(result, 'file', ''))
      for line in readfile(result.file, '', 4096)
        let rev = ghostgit#util#FnameEscape(matchstr(line, '\<https\=://[^[:space:]<>]*[^[:space:]<>.,;:"''!?]'))
        if len(rev)
          return s:browser_open(rev, a:mods, a:bang)
        endif
      endfor
      return 'echoerr ' . string('ghostgit: no URL found in output of :Git')
    endif
    if empty(remote) && expanded =~# '^[^-./:^~][^:^~]*$' && !empty(dir)
      let config = ghostgit#config#Config(dir)
      if !empty(ghostgit#config#Get('remote.' . expanded . '.url', config))
        let remote = expanded
        let expanded = ''
      endif
    endif
    if empty(expanded)
      let bufname = &buftype =~# '^\%(nofile\|terminal\)$' ? '' : bufname('%')
      let expanded = ghostgit#core#DirRev(bufname)[1]
      if empty(expanded)
        let expanded = ghostgit#buffer#Path(bufname, ':(top)', dir)
      endif
      if a:count > 0 && has_key(result, 'origin_bufnr') && a:range != 2
        let blame = ghostgit#blame#CommitFileLnum(getline(a:count))
        if len(blame[0])
          let expanded = blame[0]
        endif
      endif
    endif
    let full = ghostgit#buffer#Generate(expanded, dir)
    let commit = ''
    let ref = ''
    let forbid_ref_as_commit = 0
    if full =~# '^ghostgit:'
      let [dir, commit, path] = ghostgit#core#DirCommitFile(full)
      if commit =~# '^\d\=$'
        let commit = ''
        let type = path =~# '^/\=$' ? 'tree' : 'blob'
      else
        let ref_match = matchlist(expanded, '^\(@{\@!\|[^:~^@]\+\)\(:\%(//\)\@!\|[~^@]\|$\)')
        let ref = get(ref_match, 1, '')
        let forbid_ref_as_commit = ref =~# '^@\=$' || ref_match[2] !~# '^:\=$'
        if empty(path) && !forbid_ref_as_commit
          let type = 'ref'
        else
          let type = ghostgit#git#ChompDefault(empty(path) ? 'commit': 'blob',
                \ ['cat-file', '-t', commit . substitute(path, '^/', ':', '')], dir)
        endif
      endif
      let path = path[1:-1]
    elseif !empty(ghostgit#core#GetTree(dir))
      let relevant_dir = ghostgit#core#ExtractGitDir(full)
      if !empty(relevant_dir)
        let dir = relevant_dir
      endif
      let path = ghostgit#buffer#Path(full, '/', dir)[1:-1]
      if empty(path) || isdirectory(full)
        let type = 'tree'
      else
        let type = 'blob'
      endif
    else
      let path = '.git/' . full[strlen(dir)+1:-1]
      let type = ''
    endif
    exe ghostgit#core#DirCheck(dir)
    if path =~# '^\.git/'
      let ref = matchstr(path, '^.git/\zs\%(refs/[^/]\+/[^/].*\|\w*HEAD\)$')
      let type = empty(ref) ? 'root': 'ref'
      let path = ''
    endif
    if empty(ref) || ref ==# 'HEAD' || ref ==# '@'
      let ref = ghostgit#git#Head(-1, dir)
    endif
    if ref =~# '^\x\{40,\}$'
      let ref = ''
    elseif !empty(ref) && ref !~# '^refs/'
      let ref = ghostgit#git#Execute(['rev-parse', '--symbolic-full-name', ref], dir).stdout[0]
      if ref !~# '^refs/'
        let ref = ''
      endif
    endif

    if !exists('l:config') || ghostgit#core#Dir(config) !=# dir
      let config = ghostgit#config#Config(dir)
    endif
    let merge = ''
    if !empty(remote) && ref =~# '^refs/remotes/[^/]\+/[^/]\|^refs/heads/[^/]'
      let merge = matchstr(ref, '^refs/\%(heads/\|remotes/[^/]\+/\)\zs.\+')
      let ref = 'refs/heads/' . merge
    elseif ref =~# '^refs/remotes/[^/]\+/[^/]'
      let remote = matchstr(ref, '^refs/remotes/\zs[^/]\+')
      let merge = matchstr(ref, '^refs/remotes/[^/]\+/\zs.\+')
      let ref = 'refs/heads/' . merge
    elseif ref =~# '^refs/heads/[^/]'
      let merge = strpart(ref, 11)
      let r = ghostgit#config#Get('branch.' . merge . '.remote', config)
      let m = ghostgit#config#Get('branch.' . merge . '.merge', config)[11:-1]
      if r ==# '.' && !empty(m)
        let r2 = ghostgit#config#Get('branch.'.m.'.remote', config)
        if r2 !~# '^\.\=$'
          let r = r2
          let m = ghostgit#config#Get('branch.'.m.'.merge', config)[11:-1]
        endif
      endif
      if r !~# '^\.\=$'
        let remote = r
      endif
      if !empty(remote)
        let remote_ref = 'refs/remotes/' . remote . '/' . merge
        if ghostgit#config#Get('push.default', config) ==# 'upstream' ||
              \ !filereadable(ghostgit#buffer#Find('.git/' . remote_ref, dir)) && empty(ghostgit#git#ChompDefault('', ['rev-parse', '--verify', remote_ref, '--'], dir))
          let merge = m
          let ref = 'refs/heads/' . merge
        endif
      endif
    endif

    if empty(remote) || remote ==# '.'
      let remote = ghostgit#config#RemoteDefault(config)
    endif
    if empty(merge) || empty(remote)
      let provider_ref = ref
    else
      let provider_ref = 'refs/remotes/' . remote . '/' . merge
    endif
    if forbid_ref_as_commit || a:count >= 0
      let ref = ''
      if type ==# 'ref'
        let type = 'commit'
      endif
    endif

    let url = s:provider_url(dir, config, remote, ref, commit, path, type, a:count, a:line1, a:range)
    if empty(url)
      return 'echoerr ' . string('ghostgit: could not determine remote URL')
    endif
    return s:browser_open(url, a:mods, a:bang)
  catch /^ghostgit:/
    return 'echoerr ' . string(v:exception)
  endtry
endfunction

" ── Provider URL ────────────────────────────────────────────────────

function! s:provider_url(dir, config, remote, ref, commit, path, type, count, line1, range) abort
  let remote_obj = ghostgit#remote#Remote(a:dir, a:remote, [], [])
  call ghostgit#job#Wait(remote_obj)
  let url = get(remote_obj, 'url', '')
  if empty(url)
    return ''
  endif

  " GitHub
  if url =~# 'github\.com'
    return s:github_url(url, a:ref, a:commit, a:path, a:type, a:count, a:line1, a:range)
  endif

  " GitLab
  if url =~# 'gitlab\.com'
    return s:gitlab_url(url, a:ref, a:commit, a:path, a:type, a:count, a:line1, a:range)
  endif

  " Bitbucket
  if url =~# 'bitbucket\.org'
    return s:bitbucket_url(url, a:ref, a:commit, a:path, a:type, a:count, a:line1, a:range)
  endif

  return url
endfunction

function! s:github_url(url, ref, commit, path, type, count, line1, range) abort
  let base = substitute(a:url, '\.git$', '', '')
  if a:type ==# 'ref'
    return base . '/tree/' . a:ref
  elseif a:type ==# 'commit'
    return base . '/commit/' . (empty(a:commit) ? a:ref : a:commit)
  elseif a:type ==# 'tree'
    let url = base . '/tree/' . (empty(a:commit) ? (empty(a:ref) ? 'HEAD' : a:ref) : a:commit)
    if !empty(a:path)
      let url .= '/' . a:path
    endif
    return url
  else
    let url = base . '/blob/' . (empty(a:commit) ? (empty(a:ref) ? 'HEAD' : a:ref) : a:commit)
    if !empty(a:path)
      let url .= '/' . a:path
    endif
    if a:count > 0
      let url .= '#L' . (a:range == 2 ? a:line1 : a:count)
    endif
    return url
  endif
endfunction

function! s:gitlab_url(url, ref, commit, path, type, count, line1, range) abort
  let base = substitute(a:url, '\.git$', '', '')
  if a:type ==# 'ref'
    return base . '/-/tree/' . a:ref
  elseif a:type ==# 'commit'
    return base . '/-/commit/' . (empty(a:commit) ? a:ref : a:commit)
  elseif a:type ==# 'tree'
    let url = base . '/-/tree/' . (empty(a:commit) ? (empty(a:ref) ? 'HEAD' : a:ref) : a:commit)
    if !empty(a:path)
      let url .= '/' . a:path
    endif
    return url
  else
    let url = base . '/-/blob/' . (empty(a:commit) ? (empty(a:ref) ? 'HEAD' : a:ref) : a:commit)
    if !empty(a:path)
      let url .= '/' . a:path
    endif
    if a:count > 0
      let url .= '#L' . (a:range == 2 ? a:line1 : a:count)
    endif
    return url
  endif
endfunction

function! s:bitbucket_url(url, ref, commit, path, type, count, line1, range) abort
  let base = substitute(a:url, '\.git$', '', '')
  if a:type ==# 'ref'
    return base . '/src/' . a:ref
  elseif a:type ==# 'commit'
    return base . '/commits/' . (empty(a:commit) ? a:ref : a:commit)
  else
    let url = base . '/src/' . (empty(a:commit) ? (empty(a:ref) ? 'HEAD' : a:ref) : a:commit)
    if !empty(a:path)
      let url .= '/' . a:path
    endif
    if a:count > 0
      let url .= '#-' . (a:range == 2 ? a:line1 : a:count)
    endif
    return url
  endif
endfunction

" ── Resolve URL ─────────────────────────────────────────────────────

function! ghostgit#browse#ResolveUrl(target, ...) abort
  let dir = a:0 ? ghostgit#core#GitDir(a:1) : ghostgit#core#GitDir()
  if empty(dir)
    return ''
  endif
  let config = ghostgit#config#Config(dir)
  let remote = ghostgit#config#RemoteDefault(config)
  let remote_obj = ghostgit#remote#Remote(dir, remote, [], [])
  call ghostgit#job#Wait(remote_obj)
  return get(remote_obj, 'url', '')
endfunction
