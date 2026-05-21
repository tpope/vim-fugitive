" autoload/ghostgit/buffer.vim — Buffer auto-commands, fugitive:// URL handling, File API
" Migrated from autoload/fugitive.vim Section: File API (lines 1664–2394)
" and Section: Buffer auto-commands (lines 2552–3303)

" ── Merge heads constant ────────────────────────────────────────────

let s:merge_heads = ['MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD']

function! s:merge_head(dir) abort
  let dir = ghostgit#buffer#Find('.git/', a:dir)
  for head in s:merge_heads
    if filereadable(dir . head)
      return head
    endif
  endfor
  return ''
endfunction

" ── Owner (commit that owns a path) ─────────────────────────────────

function! s:owner(path, ...) abort
  let dir = a:0 ? ghostgit#core#Dir(a:1) : ghostgit#core#Dir()
  if empty(dir)
    return ''
  endif
  let actualdir = ghostgit#buffer#Find('.git/', dir)
  let [pdir, commit, file] = ghostgit#core#DirCommitFile(a:path)
  if ghostgit#core#SameRepo(dir, pdir)
    if commit =~# '^\x\{40,\}$'
      return commit
    elseif commit ==# '2'
      return '@'
    elseif commit ==# '0'
      return ''
    endif
    let merge_head = s:merge_head(dir)
    if empty(merge_head)
      return ''
    endif
    if commit ==# '3'
      return merge_head
    elseif commit ==# '1'
      return ghostgit#git#TreeChomp('merge-base', 'HEAD', merge_head, '--')
    endif
  endif
  let path = fnamemodify(a:path, ':p')
  if ghostgit#util#Cpath(actualdir, strpart(path, 0, len(actualdir))) && a:path =~# 'HEAD$'
    return strpart(path, len(actualdir))
  endif
  let refs = ghostgit#buffer#Find('.git/refs', dir)
  if ghostgit#util#Cpath(refs . '/', path[0 : len(refs)]) && path !~# '[\/]$'
    return strpart(path, len(refs) - 4)
  endif
  return ''
endfunction

" ── Dir URL prefix ──────────────────────────────────────────────────

if exists('+shellslash')
  function! s:dir_url_prefix(dir) abort
    let gd = ghostgit#core#GitDir(a:dir)
    return 'ghostgit://' . (gd =~# '^[^/]' ? '/' : '') . ghostgit#util#PathUrlEncode(gd) . '//'
  endfunction
else
  function! s:dir_url_prefix(dir) abort
    return 'ghostgit://' . ghostgit#util#PathUrlEncode(ghostgit#core#GitDir(a:dir)) . '//'
  endfunction
endif

" ── Find object ─────────────────────────────────────────────────────

function! ghostgit#buffer#Find(object, ...) abort
  if type(a:object) == type(0)
    let name = bufname(a:object)
    return ghostgit#util#VimSlash(name =~# '^$\|^/\|^\a\+:' ? name : getcwd() . '/' . name)
  elseif a:object =~# '^[~$]'
    let prefix = matchstr(a:object, '^[~$]\i*')
    let owner = expand(prefix)
    return ghostgit#util#VimSlash(ghostgit#util#VimPath((len(owner) ? owner : prefix) . strpart(a:object, len(prefix))))
  endif
  let rev = ghostgit#util#Slash(a:object)
  if rev =~# '^\a\+://' && rev !~# '^ghostgit:'
    return rev
  elseif rev =~# '^$\|^/\|^\%(\a\a\+:\).*\%(//\|::\)' . (has('win32') ? '\|^\a:/' : '')
    return ghostgit#util#VimSlash(a:object)
  elseif rev =~# '^\.\.\=\%(/\|$\)'
    return ghostgit#util#VimSlash(simplify(getcwd() . '/' . a:object))
  endif
  let dir = a:0 ? ghostgit#core#GitDir(a:1) : ghostgit#core#GitDir()
  if empty(dir)
    let file = matchstr(a:object, '^\%(:\d:\|[^:]*:\)\zs\%(\.\.\=$\|\.\.\=/.*\|/.*\|\w:/.*\)')
    let dir = ghostgit#core#ExtractGitDir(file)
    if empty(dir)
      return ''
    endif
  endif
  let tree = ghostgit#core#WorkTree(dir)
  let urlprefix = s:dir_url_prefix(dir)
  let base = len(tree) ? tree : urlprefix . '0'
  if rev ==# '.git'
    let f = len(tree) && len(getftype(tree . '/.git')) ? tree . '/.git' : dir
  elseif rev =~# '^\.git/'
    let f = strpart(rev, 5)
    let fdir = simplify(ghostgit#core#ActualDir(dir) . '/')
    let cdir = simplify(ghostgit#core#CommonDir(dir) . '/')
    if f =~# '^\.\./\.\.\%(/\|$\)'
      let f = simplify(len(tree) ? tree . f[2:-1] : fdir . f)
    elseif f =~# '^\.\.\%(/\|$\)'
      let f = ghostgit#util#PathJoin(base, f[2:-1])
    elseif cdir !=# fdir && (
          \ f =~# '^\%(config\|hooks\|info\|logs/refs\|objects\|refs\|worktrees\)\%(/\|$\)' ||
          \ f !~# '^\%(index$\|index\.lock$\|\w*MSG$\|\w*HEAD$\|logs/\w*HEAD$\|logs$\|rebase-\w\+\)\%(/\|$\)' &&
          \ getftime(fdir . f) < 0 && getftime(cdir . f) >= 0)
      let f = simplify(cdir . f)
    else
      let f = simplify(fdir . f)
    endif
  elseif rev ==# ':/'
    let f = tree
  elseif rev =~# '^\.\%(/\|$\)'
    let f = ghostgit#util#PathJoin(base, rev[1:-1])
  elseif rev =~# '^::\%(/\|\a\+\:\)'
    let f = rev[2:-1]
  elseif rev =~# '^::\.\.\=\%(/\|$\)'
    let f = simplify(getcwd() . '/' . rev[2:-1])
  elseif rev =~# '^::'
    let f = ghostgit#util#PathJoin(base, '/' . rev[2:-1])
  elseif rev =~# '^:\%([0-3]:\)\=\.\.\=\%(/\|$\)\|^:[0-3]:\%(/\|\a\+:\)'
    let f = rev =~# '^:\%([0-3]:\)\=\.' ? simplify(getcwd() . '/' . matchstr(rev, '\..*')) : rev[3:-1]
    if ghostgit#util#Cpath(base . '/', (f . '/')[0 : len(base)])
      let f = ghostgit#util#PathJoin(urlprefix, +matchstr(rev, '^:\zs\d\ze:') . '/' . strpart(f, len(base) + 1))
    else
      let altdir = ghostgit#core#ExtractGitDir(f)
      if len(altdir) && !ghostgit#util#Cpath(dir, altdir)
        return ghostgit#buffer#Find(a:object, altdir)
      endif
    endif
  elseif rev =~# '^:[0-3]:'
    let f = ghostgit#util#PathJoin(urlprefix, rev[1] . '/' . rev[3:-1])
  elseif rev ==# ':'
    let f = urlprefix
  elseif rev =~# '^:(\%(top\|top,literal\|literal,top\|literal\))'
    let f = matchstr(rev, ')\zs.*')
    if f=~# '^\.\.\=\%(/\|$\)'
      let f = simplify(getcwd() . '/' . f)
    elseif f !~# '^/\|^\%(\a\a\+:\).*\%(//\|::\)' . (has('win32') ? '\|^\a:/' : '')
      let f = ghostgit#util#PathJoin(base, '/' . f)
    endif
  elseif rev =~# '^:/\@!'
    let f = ghostgit#util#PathJoin(urlprefix, '0/' . rev[1:-1])
  else
    let commit = matchstr(rev, '^\%([^:.-]\|\.\.[^/:]\)[^:]*\|^:.*')
    let file = substitute(matchstr(rev, '^\%([^:.-]\|\.\.[^/:]\)[^:]*\zs:.*'), '^:', '/', '')
    if file =~# '^/\.\.\=\%(/\|$\)\|^//\|^/\a\+:'
      let file = file =~# '^/\.' ? simplify(getcwd() . file) : file[1:-1]
      if ghostgit#util#Cpath(base . '/', (file . '/')[0 : len(base)])
        let file = '/' . strpart(file, len(base) + 1)
      else
        let altdir = ghostgit#core#ExtractGitDir(file)
        if len(altdir) && !ghostgit#util#Cpath(dir, altdir)
          return ghostgit#buffer#Find(a:object, altdir)
        endif
        return file
      endif
    endif
    let commits = split(commit, '\.\.\.-\@!', 1)
    if len(commits) == 2
      call map(commits, 'empty(v:val) ? "@" : v:val')
      let commit = matchstr(ghostgit#git#ChompDefault('', [dir, 'merge-base'] + commits + ['--']), '\<[0-9a-f]\{40,\}\>')
    endif
    if commit !~# '^[0-9a-f]\{40,\}$\|^$'
      let commit = matchstr(ghostgit#git#ChompDefault('', [dir, 'rev-parse', '--verify', commit . (len(file) ? '^{}' : ''), '--']), '\<[0-9a-f]\{40,\}\>')
      if empty(commit) && len(file)
        let commit = repeat('0', 40)
      endif
    endif
    if len(commit)
      let f = ghostgit#util#PathJoin(urlprefix, commit . file)
    else
      let f = ghostgit#util#PathJoin(base, '/' . substitute(rev, '^:/:\=\|^[^:]\+:', '', ''))
    endif
  endif
  return ghostgit#util#VimSlash(f)
endfunction

" ── Generate (simplified Find) ──────────────────────────────────────

function! ghostgit#buffer#Generate(object, ...) abort
  let dir = a:0 ? a:1 : ghostgit#core#GitDir()
  let f = ghostgit#buffer#Find(a:object, dir)
  if !empty(f)
    return f
  elseif a:object ==# ':/'
    return len(dir) ? ghostgit#util#VimSlash(s:dir_url_prefix(dir) . '0') : '.'
  endif
  let file = matchstr(a:object, '^\%(:\d:\|[^:]*:\)\=\zs.*')
  return empty(file) ? '' : fnamemodify(ghostgit#util#VimSlash(file), ':p')
endfunction

" ── Object name ─────────────────────────────────────────────────────

function! s:buf_name(var) abort
  if a:var ==# '%'
    return bufname(get(ghostgit#job#TempState(), 'origin_bufnr', ''))
  elseif a:var =~# '^#\d*$'
    let nr = get(ghostgit#job#TempState(+a:var[1:-1]), 'origin_bufnr', '')
    return bufname(nr ? nr : +a:var[1:-1])
  else
    return expand(a:var)
  endif
endfunction

function! ghostgit#buffer#Object(...) abort
  let dir = a:0 > 1 ? ghostgit#core#Dir(a:2) : ghostgit#core#Dir()
  let [fdir, rev] = ghostgit#core#DirRev(a:0 ? a:1 : @%)
  if !ghostgit#core#SameRepo(dir, fdir)
    let rev = ''
  endif
  let tree = ghostgit#core#GetTree(dir)
  let full = a:0 ? a:1 : s:buf_name('%')
  let full = fnamemodify(full, ':p' . (ghostgit#util#Slash(full) =~# '/$' ? '' : ':s?/$??'))
  if empty(rev) && empty(tree)
    return ghostgit#core#GitPath(full)
  elseif empty(rev)
    let rev = ghostgit#buffer#Path(full, './', dir)
    if rev =~# '^\./.git\%(/\|$\)'
      return ghostgit#core#GitPath(full)
    endif
  endif
  if rev !~# '^\.\%(/\|$\)' || ghostgit#util#Cpath(getcwd(), tree)
    return rev
  else
    return ghostgit#core#GitPath(tree . rev[1:-1])
  endif
endfunction

" ── Expand variables ────────────────────────────────────────────────

let s:var = '\%(<\%(cword\|cWORD\|cexpr\|cfile\|sfile\|slnum\|afile\|abuf\|amatch' . (has('clientserver') ? '\|client' : '') . '\)>\|%\|#<\=\d\+\|##\=\)'
let s:flag = '\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)'
let s:expand = '\%(\(' . s:var . '\)\(' . s:flag . '*\)\(:S\)\=\)'
let s:commit_expand = '!\\\@!#\=\d*\|!%'

function! ghostgit#buffer#Expand(object) abort
  let cwd = getcwd()
  return substitute(a:object,
        \ '\%(\%(^\|[^\\]\)\%(\\\\\)*\)\@<=\%(' . s:expand . '\)',
        \ '\=ghostgit#buffer#ExpandVar(submatch(1), submatch(2), submatch(3), cwd)', 'g')
endfunction

function! ghostgit#buffer#ExpandVar(other, var, flags, ...) abort
  let cwd = a:0 ? a:1 : getcwd()
  if a:other =~# '^\'
    return a:other[1:-1]
  elseif a:other =~# '^'''
    return substitute(a:other[1:-2], "''", "'", "g")
  elseif a:other =~# '^"'
    return substitute(a:other[1:-2], '""', '"', "g")
  elseif a:other =~# '^[!`]'
    let buffer = s:buf_name(a:other =~# '[0-9#]' ? '#' . matchstr(a:other, '\d\+') : '%')
    let owner = s:owner(buffer)
    return len(owner) ? owner : '@'
  elseif a:other =~# '^\~[~.]$'
    return ghostgit#util#Slash(getcwd())
  elseif len(a:other)
    return expand(a:other)
  elseif a:var ==# '<cfile>'
    return expand('<cfile>')
  elseif a:var ==# '<cword>'
    return expand('<cword>')
  elseif a:var ==# '<cWORD>'
    return expand('<cWORD>')
  elseif a:var ==# '<cexpr>'
    return expand('<cexpr>')
  elseif a:var ==# '<sfile>'
    return expand('<sfile>')
  elseif a:var ==# '<slnum>'
    return expand('<slnum>')
  elseif a:var ==# '<afile>'
    return expand('<afile>')
  elseif a:var ==# '<abuf>'
    return expand('<abuf>')
  elseif a:var ==# '<amatch>'
    return expand('<amatch>')
  elseif a:var =~# '^#\d*$'
    let nr = +a:var[1:-1]
    return s:buf_name(a:var)
  elseif a:var ==# '%'
    return s:buf_name('%')
  elseif a:var ==# '##'
    return join(map(range(1, winnr('$')), 'bufname(winbufnr(v:val))'), ' ')
  elseif a:var ==# '#'
    return bufname('#')
  endif
  return ''
endfunction

" ── Relative path ───────────────────────────────────────────────────

function! s:dot_relative(path, ...) abort
  let cwd = a:0 ? a:1 : getcwd()
  let path = substitute(a:path, '^[~$]\i*', '\=expand(submatch(0))', '')
  if len(cwd) && ghostgit#util#Cpath(cwd . '/', (path . '/')[0 : len(cwd)])
    return '.' . strpart(path, len(cwd))
  endif
  return a:path
endfunction

function! ghostgit#buffer#Relative(...) abort
  let path = a:0 ? a:1 : @%
  let dir = a:0 > 1 ? ghostgit#core#Dir(a:2) : ghostgit#core#Dir()
  let tree = ghostgit#core#GetTree(dir)
  if empty(tree)
    return s:dot_relative(ghostgit#util#Slash(fnamemodify(path, ':p')), getcwd())
  endif
  let urlprefix = s:dir_url_prefix(dir)
  let [pdir, commit, file] = ghostgit#core#DirCommitFile(path)
  if !empty(commit)
    return ':' . (commit =~# '^\d$' ? commit : '0') . (empty(file) ? '' : file[1:-1])
  elseif ghostgit#util#Slash(path) =~# '^ghostgit://'
    return s:dot_relative(ghostgit#util#Slash(ghostgit#core#Real(path)), tree)
  else
    return s:dot_relative(ghostgit#util#Slash(fnamemodify(path, ':p')), tree)
  endif
endfunction

" ── File API (virtual filesystem for ghostgit:// URLs) ──────────────

let s:trees = {}
let s:indexes = {}

function! ghostgit#buffer#Simplify(url) abort
  return substitute(a:url, '\c^ghostitive://\zs.\{-\}\ze//', '\=ghostgit#util#Slash(simplify(ghostgit#util#UrlDecode(submatch(0))))', '')
endfunction

function! ghostgit#buffer#Resolve(url) abort
  if a:url =~# '^ghostgit://'
    return a:url
  endif
  return resolve(a:url)
endfunction

function! ghostgit#buffer#GetFtime(url) abort
  if a:url !~# '^ghostgit://'
    return getftime(a:url)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir)
    return -1
  endif
  if commit =~# '^\d$'
    let entry = ghostgit#buffer#LsTree(dir, commit, file)
    return get(entry, 'mtime', -1)
  elseif commit =~# '^\x\{40,\}$'
    return getftime(ghostgit#core#Real(a:url))
  endif
  return -1
endfunction

function! ghostgit#buffer#GetFsize(url) abort
  if a:url !~# '^ghostgit://'
    return getfsize(a:url)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir) || empty(file)
    return -1
  endif
  if commit =~# '^\d$'
    let entry = ghostgit#buffer#LsTree(dir, commit, file)
    return get(entry, 'size', -1)
  endif
  return getfsize(ghostgit#core#Real(a:url))
endfunction

function! ghostgit#buffer#GetFtype(url) abort
  if a:url !~# '^ghostgit://'
    return getftype(a:url)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir)
    return ''
  endif
  if commit =~# '^\d$'
    let entry = ghostgit#buffer#LsTree(dir, commit, file)
    return get(entry, 'type', '')
  elseif commit =~# '^\x\{40,\}$'
    if empty(file)
      return 'dir'
    endif
    return getftype(ghostgit#core#Real(a:url))
  elseif commit ==# '0'
    return filereadable(ghostgit#core#Real(a:url)) ? 'file' : ''
  endif
  return ''
endfunction

function! ghostgit#buffer#FileReadable(url) abort
  if a:url !~# '^ghostgit://'
    return filereadable(a:url)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  return !empty(dir) && !empty(file)
endfunction

function! ghostgit#buffer#FileWritable(url) abort
  if a:url !~# '^ghostgit://'
    return filewritable(a:url)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir) || empty(file)
    return 0
  endif
  if commit ==# '0'
    return filewritable(ghostgit#core#Real(a:url))
  endif
  return 0
endfunction

function! ghostgit#buffer#IsDirectory(url) abort
  if a:url !~# '^ghostgit://'
    return isdirectory(a:url)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir)
    return 0
  endif
  if commit =~# '^\d$'
    let entry = ghostgit#buffer#LsTree(dir, commit, file)
    return get(entry, 'type', '') ==# 'tree'
  elseif commit =~# '^\x\{40,\}$'
    return empty(file) || isdirectory(ghostgit#core#Real(a:url))
  endif
  return 0
endfunction

function! ghostgit#buffer#GetFperm(url) abort
  if a:url !~# '^ghostgit://'
    return getfperm(a:url)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir) || empty(file)
    return ''
  endif
  if commit =~# '^\d$'
    let entry = ghostgit#buffer#LsTree(dir, commit, file)
    let mode = get(entry, 'mode', '')
    if mode =~# '^100.\{3\}$'
      return mode[3] ==# '7' ? 'rwxr-xr-x' : 'rw-r--r--'
    endif
    return ''
  endif
  return getfperm(ghostgit#core#Real(a:url))
endfunction

function! ghostgit#buffer#SetFperm(url, perm) abort
  if a:url !~# '^ghostgit://'
    return setfperm(a:url, a:perm)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir) || empty(file) || commit !=# '0'
    return 0
  endif
  return setfperm(ghostgit#core#Real(a:url), a:perm)
endfunction

function! ghostgit#buffer#ReadFile(url, ...) abort
  if a:url !~# '^ghostgit://'
    return call('readfile', [a:url] + a:000)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir) || empty(file)
    return []
  endif
  if commit =~# '^\d$'
    let r = ghostgit#git#Execute([dir, 'cat-file', '-p', commit . ':' . file[1:-1]])
    return split(join(r.stdout, "\n"), "\n", 1)
  endif
  return call('readfile', [ghostgit#core#Real(a:url)] + a:000)
endfunction

function! ghostgit#buffer#WriteFile(lines, url, ...) abort
  if a:url !~# '^ghostgit://'
    return call('writefile', [a:lines, a:url] + a:000)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir) || empty(file) || commit !=# '0'
    return 0
  endif
  return call('writefile', [a:lines, ghostgit#core#Real(a:url)] + a:000)
endfunction

function! ghostgit#buffer#Glob(url, ...) abort
  if a:url !~# '^ghostgit://'
    return call('glob', [a:url] + a:000)
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if empty(dir)
    return ''
  endif
  if commit =~# '^\d$'
    let tree = commit ==# '0' ? '' : commit
    let prefix = empty(tree) ? '' : tree . ':'
    let r = ghostgit#git#Execute([dir, 'ls-tree', '-r', '--name-only', tree . substitute(file, '^/', ':', '')])
    return join(r.stdout, "\n")
  endif
  return call('glob', [ghostgit#core#Real(a:url)] + a:000)
endfunction

function! ghostgit#buffer#Delete(url, ...) abort
  if a:url !~# '^ghostgit://'
    return call('delete', [a:url] + a:000)
  endif
  return -1
endfunction

" ── LsTree cache helper ─────────────────────────────────────────────

function! ghostgit#buffer#LsTree(dir, stage, file) abort
  let trees = ghostgit#state#GetTrees()
  let key = a:dir . ':' . a:stage
  if !has_key(trees, key)
    let r = ghostgit#git#Execute([a:dir, 'ls-files', '--stage', '--', '.'])
    let trees[key] = {}
    for line in r.stdout
      let parts = split(line)
      if len(parts) >= 3
        let mode = parts[0]
        let sha = parts[1]
        let stage = parts[2][0]
        let path = join(parts[3:], ' ')
        let trees[key][path] = {'mode': mode, 'sha': sha, 'stage': stage, 'type': mode[0] ==# '4' ? 'tree' : 'blob', 'size': 0}
      endif
    endfor
  endif
  return get(trees[key], a:file[1:-1], {})
endfunction
