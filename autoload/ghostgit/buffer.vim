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
  return substitute(a:url, '\c^ghostgit://\zs.\{-\}\ze//', '\=ghostgit#util#Slash(simplify(ghostgit#util#UrlDecode(submatch(0))))', '')
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
  elseif commit =~# '^\x\{40,\}$'
    return getfsize(ghostgit#core#Real(a:url))
  endif
  return -1
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
  let key = a:dir
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
        let trees[key][path . ':' . stage] = {'mode': mode, 'sha': sha, 'stage': stage, 'type': mode[0] ==# '4' ? 'tree' : 'blob', 'size': -1}
      endif
    endfor
  endif
  return get(trees[key], a:file[1:-1] . ':' . a:stage, {})
endfunction

" ── BufReadCmd (was fugitive#BufReadCmd) ────────────────────────────

function! ghostgit#buffer#BufReadCmd(...) abort
  let amatch = a:0 ? a:1 : expand('<amatch>')
  let [dir, rev] = ghostgit#core#DirRev(amatch)
  if empty(dir)
    return 'echo "Invalid Ghostgit URL"'
  endif
  call ghostgit#core#InitializeBuffer(dir)
  if rev ==# ':'
    return ghostgit#status#BufReadStatus(v:cmdbang)
  endif
  try
    if rev =~# '^:\d$'
      let b:ghostgit_type = 'stage'
    else
      let r = ghostgit#git#Execute([dir, 'cat-file', '-t', rev])
      let b:ghostgit_type = get(r.stdout, 0, '')
      if r.exit_status && rev =~# '^:0'
        let r = ghostgit#git#Execute([dir, 'write-tree', '--prefix=' . rev[3:-1]])
        let sha = get(r.stdout, 0, '')
        let b:ghostgit_type = 'tree'
      endif
      if r.exit_status
        let error = substitute(join(r.stderr, "\n"), "\n*$", '', '')
        unlet b:ghostgit_type
        setlocal noswapfile
        if empty(&bufhidden)
          setlocal bufhidden=delete
        endif
        if rev =~# '^:\d:'
          let &l:readonly = !filewritable(ghostgit#buffer#Find('.git/index', dir))
          return 'doautocmd BufNewFile'
        else
          setlocal readonly nomodifiable
          return 'doautocmd BufNewFile|echo ' . string(error)
        endif
      elseif b:ghostgit_type !~# '^\%(tag\|commit\|tree\|blob\)$'
        return "echoerr ".string("ghostgit: unrecognized git type '".b:ghostgit_type."'")
      endif
      if !exists('b:ghostgit_display_format') && b:ghostgit_type != 'blob'
        let b:ghostgit_display_format = +getbufvar('#','ghostgit_display_format')
      endif
    endif

    if b:ghostgit_type !=# 'blob'
      setlocal nomodeline
    endif

    setlocal noreadonly modifiable
    let pos = getpos('.')
    silent keepjumps %delete_
    setlocal endofline

    let events = ['User GhostgitObject', 'User Ghostgit' . substitute(b:ghostgit_type, '^\l', '\u&', '')]

    try
      if b:ghostgit_type !=# 'blob'
        setlocal foldmarker=<<<<<<<<,>>>>>>>>
      endif
      exe ghostgit#util#DoAutocmd('BufReadPre')
      if b:ghostgit_type ==# 'tree'
        let b:ghostgit_display_format = b:ghostgit_display_format % 2
        if b:ghostgit_display_format
          call s:ReplaceCmd([dir, 'ls-tree', exists('sha') ? sha : rev])
        else
          if !exists('sha')
            let sha = ghostgit#git#TreeChomp(dir, 'rev-parse', '--verify', rev, '--')
          endif
          call s:ReplaceCmd([dir, 'show', '--no-color', sha])
        endif
      elseif b:ghostgit_type ==# 'tag'
        let b:ghostgit_display_format = b:ghostgit_display_format % 2
        if b:ghostgit_display_format
          call s:ReplaceCmd([dir, 'cat-file', b:ghostgit_type, rev])
        else
          call s:ReplaceCmd([dir, 'cat-file', '-p', rev])
        endif
      elseif b:ghostgit_type ==# 'commit'
        let b:ghostgit_display_format = b:ghostgit_display_format % 2
        if b:ghostgit_display_format
          call s:ReplaceCmd([dir, 'cat-file', b:ghostgit_type, rev])
        else
          call s:ReplaceCmd([dir, '-c', 'diff.noprefix=false', '-c', 'log.showRoot=false', 'show', '--no-color', '-m', '--first-parent', '--pretty=format:tree%x20%T%nparent%x20%P%nauthor%x20%an%x20<%ae>%x20%ad%ncommitter%x20%cn%x20<%ce>%x20%cd%nencoding%x20%e%n%n%B', rev])
          keepjumps 1
          keepjumps call search('^parent ')
          if getline('.') ==# 'parent '
            silent lockmarks keepjumps delete_
          else
            silent exe (exists(':keeppatterns') ? 'keeppatterns' : '') 'keepjumps s/\m\C\%(^parent\)\@<! /\rparent /e' . (&gdefault ? '' : 'g')
          endif
          keepjumps let lnum = search('^encoding \%(<unknown>\)\=$','W',line('.')+3)
          if lnum
            silent lockmarks keepjumps delete_
          end
          silent exe (exists(':keeppatterns') ? 'keeppatterns' : '') 'keepjumps 1,/^diff --git\|\%$/s/\r$//e'
          keepjumps 1
        endif
      elseif b:ghostgit_type ==# 'stage'
        call s:ReplaceCmd([dir, 'ls-files', '--stage'])
      elseif b:ghostgit_type ==# 'blob'
        let blob_or_filters = rev =~# ':' && ghostgit#git#GitVersion(2, 11) ? '--filters' : 'blob'
        call s:ReplaceCmd([dir, 'cat-file', blob_or_filters, rev])
      endif
    finally
      keepjumps call setpos('.',pos)
      setlocal nomodified noswapfile
      let modifiable = rev =~# '^:.:' && b:ghostgit_type !=# 'tree'
      if modifiable
        let events = ['User GhostgitStageBlob']
      endif
      let &l:readonly = !modifiable || !filewritable(ghostgit#buffer#Find('.git/index', dir))
      if empty(&bufhidden)
        setlocal bufhidden=delete
      endif
      let &l:modifiable = modifiable
      if b:ghostgit_type !=# 'blob'
        call ghostgit#util#Map('n', 'a', ":<C-U>let b:ghostgit_display_format += v:count1<Bar>exe ghostgit#buffer#BufReadCmd(@%)<CR>", '<silent>')
        call ghostgit#util#Map('n', 'i', ":<C-U>let b:ghostgit_display_format -= v:count1<Bar>exe ghostgit#buffer#BufReadCmd(@%)<CR>", '<silent>')
        setlocal filetype=git
      endif
    endtry

    setlocal modifiable

    return ghostgit#util#DoAutocmd('BufReadPost') .
          \ (modifiable ? '' : '|setl nomodifiable') . '|' .
          \ call('ghostgit#util#DoAutocmd', events)
  catch /^ghostgit:/
    return 'echoerr ' . string(v:exception)
  endtry
endfunction

" ── BufWriteCmd (was fugitive#BufWriteCmd) ──────────────────────────

function! ghostgit#buffer#BufWriteCmd(...) abort
  return ghostgit#buffer#FileWriteCmd(a:0 ? a:1 : expand('<amatch>'), 1)
endfunction

" ── FileReadCmd (was fugitive#FileReadCmd) ──────────────────────────

function! ghostgit#buffer#FileReadCmd(...) abort
  let amatch = a:0 ? a:1 : expand('<amatch>')
  let [dir, rev] = ghostgit#core#DirRev(amatch)
  let line = a:0 > 1 ? a:2 : line("'[")
  if empty(dir)
    return 'noautocmd ' . line . 'read ' . ghostgit#util#FnameEscape(amatch)
  endif
  if rev !~# ':' && ghostgit#git#ChompDefault('', [dir, 'cat-file', '-t', rev]) =~# '^\%(commit\|tag\)$'
    let cmd = [dir, 'log', '--pretty=format:%B', '-1', rev, '--']
  elseif rev ==# ':'
    let cmd = [dir, 'status', '--short']
  else
    let cmd = [dir, 'cat-file', '-p', rev, '--']
  endif
  let temp = tempname()
  let [err, exec_error] = ghostgit#git#StdoutToFile(temp, cmd)
  if exec_error
    call delete(temp)
    return 'noautocmd ' . line . 'read ' . ghostgit#util#FnameEscape(amatch)
  else
    return 'silent keepalt ' . line . 'read ' . ghostgit#util#FnameEscape(temp) . '|call delete(' . string(temp) . ')'
  endif
endfunction

" ── FileWriteCmd (was fugitive#FileWriteCmd) ─────────────────────────

function! ghostgit#buffer#FileWriteCmd(...) abort
  let temp = tempname()
  let amatch = a:0 ? a:1 : expand('<amatch>')
  let autype = a:0 > 1 ? 'Buf' : 'File'
  if exists('#' . autype . 'WritePre')
    execute ghostgit#util#DoAutocmd(autype . 'WritePre ' . ghostgit#util#FnameEscape(amatch))
  endif
  try
    let [dir, commit, file] = ghostgit#core#DirCommitFile(amatch)
    if commit !~# '^[0-3]$' || !v:cmdbang && (line("'[") != 1 || line("']") != line('$'))
      return "noautocmd '[,']write" . (v:cmdbang ? '!' : '') . ' ' . ghostgit#util#FnameEscape(amatch)
    endif
    silent execute "noautocmd keepalt '[,']write ".temp
    let hash = ghostgit#git#TreeChomp(dir, '--literal-pathspecs', 'hash-object', '-w', '--', ghostgit#core#GitPath(temp))
    let old_mode = matchstr(ghostgit#git#ChompDefault('', [dir, 'ls-files', '--stage', '.' . file]), '^\d\+')
    if empty(old_mode)
      let old_mode = executable(ghostgit#core#WorkTree(dir) . file) ? '100755' : '100644'
    endif
    let error = s:UpdateIndex(dir, [old_mode, hash, commit, file[1:-1]])
    if empty(error)
      setlocal nomodified
      if exists('#' . autype . 'WritePost')
        execute ghostgit#util#DoAutocmd(autype . 'WritePost ' . ghostgit#util#FnameEscape(amatch))
      endif
      exe ghostgit#status#DidChange(dir)
      return ''
    else
      return 'echoerr '.string('ghostgit: '.error)
    endif
  catch /^ghostgit:/
    return 'echoerr ' . string(v:exception)
  finally
    call delete(temp)
  endtry
endfunction

" ── SourceCmd (was fugitive#SourceCmd) ──────────────────────────────

function! ghostgit#buffer#SourceCmd(...) abort
  let amatch = a:0 ? a:1 : expand('<amatch>')
  let temp = s:BlobTemp(amatch)
  if empty(temp)
    return 'noautocmd source ' . ghostgit#util#FnameEscape(amatch)
  endif
  if !exists('g:virtual_scriptnames')
    let g:virtual_scriptnames = {}
  endif
  let g:virtual_scriptnames[temp] = amatch
  return 'source ' . ghostgit#util#FnameEscape(temp)
endfunction

" ── Replace command content ─────────────────────────────────────────

function! s:ReplaceCmd(cmd) abort
  let temp = tempname()
  let [err, exec_error] = ghostgit#git#StdoutToFile(temp, a:cmd)
  if exec_error
    throw 'ghostgit: ' . (len(err) ? substitute(err, "\n$", '', '') : 'unknown error running ' . string(a:cmd))
  endif
  setlocal noswapfile
  silent exe 'lockmarks keepalt noautocmd 0read ++edit' ghostgit#util#FnameEscape(temp)
  if &foldenable && foldlevel('$') > 0
    set nofoldenable
    silent keepjumps $delete _
    set foldenable
  else
    silent keepjumps $delete _
  endif
  call delete(temp)
endfunction

" ── Update index ────────────────────────────────────────────────────

function! s:UpdateIndex(dir, info) abort
  let [mode, hash, stage, path] = a:info
  let r = ghostgit#git#Execute([a:dir, 'update-index', '--add', '--cacheinfo', mode.','.hash.','.path])
  return r.exit_status ? join(r.stderr, "\n") : ''
endfunction

" ── Blob temp (was s:BlobTemp) ───────────────────────────────────────

function! s:BlobTemp(url) abort
  let [dir, rev] = ghostgit#core#DirRev(a:url)
  if empty(dir)
    return ''
  endif
  let temp = tempname()
  let [err, exec_error] = ghostgit#git#StdoutToFile(temp, [dir, 'cat-file', 'blob', rev])
  if exec_error
    call delete(temp)
    return ''
  endif
  return temp
endfunction
