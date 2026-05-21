" autoload/ghostgit/core.vim — Bootstrap, git dir detection, root repo, path normalization
" Migrated from plugin/fugitive.vim (FugitiveGitDir, FugitiveExtractGitDir, etc.)
" and autoload/fugitive.vim Section: Git (s:Dir, s:Tree, etc.)

" ── Constants ───────────────────────────────────────────────────────

let s:bad_git_dir = '/$\|^ghostgit:'

" ── Git dir detection (was FugitiveGitDir) ──────────────────────────

function! ghostgit#core#GitDir(...) abort
  if v:version < 704
    return ''
  elseif !a:0 || type(a:1) == type(0) && a:1 < 0 || a:1 is# get(v:, 'true', -1)
    if exists('g:ghostgit_event')
      return g:ghostgit_event
    endif
    let dir = get(b:, 'git_dir', '')
    if empty(dir) && (empty(bufname('')) && &filetype !=# 'netrw' || &buftype =~# '^\%(nofile\|acwrite\|quickfix\|terminal\|prompt\)$')
      return ghostgit#core#ExtractGitDir(getcwd())
    elseif (!exists('b:git_dir') || b:git_dir =~# s:bad_git_dir) && &buftype =~# '^\%(nowrite\)\=$'
      let b:git_dir = ghostgit#core#ExtractGitDir(bufnr(''))
      return b:git_dir
    endif
    return dir =~# s:bad_git_dir ? '' : dir
  elseif type(a:1) == type(0) && a:1 isnot# 0
    if a:1 == bufnr('') && (!exists('b:git_dir') || b:git_dir =~# s:bad_git_dir) && &buftype =~# '^\%(nowrite\)\=$'
      let b:git_dir = ghostgit#core#ExtractGitDir(a:1)
    endif
    let dir = getbufvar(a:1, 'git_dir')
    return dir =~# s:bad_git_dir ? '' : dir
  elseif type(a:1) == type('')
    return substitute(ghostgit#util#Slash(a:1), '/$', '', '')
  elseif type(a:1) == type({})
    return get(a:1, 'ghostgit_dir', get(a:1, 'git_dir', ''))
  else
    return ''
  endif
endfunction

" ── Read file helper ────────────────────────────────────────────────

function! s:read_file(path, line_count) abort
  if v:version < 800 && !filereadable(a:path)
    return []
  endif
  try
    return readfile(a:path, 'b', a:line_count)
  catch
    return []
  endtry
endfunction

" ── Is git dir check ────────────────────────────────────────────────

function! ghostgit#core#IsGitDir(path) abort
  if !a:0 || type(a:1) !=# type('')
    return !empty(ghostgit#core#GitDir(a:0 ? a:1 : -1))
  endif
  let path = substitute(a:1, '[\/]$', '', '') . '/'
  return len(path) && getfsize(path.'HEAD') > 10 && (
        \ isdirectory(path.'objects') && isdirectory(path.'refs') ||
        \ getftype(path.'commondir') ==# 'file')
endfunction

" ── Resolve git dir (handles gitdir files, symlinks) ────────────────

function! ghostgit#core#ResolveGitDir(git_dir) abort
  let type = getftype(a:git_dir)
  if type ==# 'dir' && ghostgit#core#IsGitDir(a:git_dir)
    return a:git_dir
  elseif type ==# 'link' && ghostgit#core#IsGitDir(a:git_dir)
    return ghostgit#util#Resolve(a:git_dir)
  elseif type !=# ''
    let line = get(s:read_file(a:git_dir, 1), 0, '')
    let file_dir = ghostgit#util#Slash(ghostgit#util#VimPath(matchstr(line, '^gitdir: \zs.*')))
    if file_dir !~# '^/\|^\a:\|^$' && a:git_dir =~# '/\.git$' && ghostgit#core#IsGitDir(a:git_dir[0:-5] . file_dir)
      return simplify(a:git_dir[0:-5] . file_dir)
    elseif file_dir =~# '^/\|^\a:' && ghostgit#core#IsGitDir(file_dir)
      return file_dir
    endif
  endif
  return ''
endfunction

" ── Tree resolution (worktree from git dir) ─────────────────────────

function! s:tree(path) abort
  if a:path =~# '/\.git$'
    return len(a:path) ==# 5 ? '/' : a:path[0:-6]
  elseif a:path ==# ''
    return ''
  endif
  let dir = ghostgit#core#ActualDir(a:path)
  let worktree_for_dir = ghostgit#state#GetWorktreeForDir()
  let dir_for_worktree = ghostgit#state#GetDirForWorktree()
  if !has_key(worktree_for_dir, dir)
    let worktree_for_dir[dir] = ''
    let ext_wtc_pat = 'v:val =~# "^\\s*worktreeConfig *= *\\%(true\\|yes\\|on\\|1\\) *$"'
    let config = s:read_file(dir . '/config', 50)
    if len(config)
      let ext_wtc_config = filter(copy(config), ext_wtc_pat)
      if len(ext_wtc_config) == 1 && filereadable(dir . '/config.worktree')
         let config += s:read_file(dir . '/config.worktree', 50)
      endif
    else
      let worktree = fnamemodify(ghostgit#util#VimPath(get(s:read_file(dir . '/gitdir', 1), '0', '')), ':h')
      if worktree ==# '.'
        unlet! worktree
      endif
      if len(filter(s:read_file(ghostgit#core#CommonDir(dir) . '/config', 50), ext_wtc_pat))
        let config = s:read_file(dir . '/config.worktree', 50)
      endif
    endif
    if len(config)
      let wt_config = filter(copy(config), 'v:val =~# "^\\s*worktree *="')
      if len(wt_config)
        let worktree = ghostgit#util#VimPath(matchstr(wt_config[0], '= *\zs.*'))
      elseif !exists('worktree')
        call filter(config,'v:val =~# "^\\s*bare *= *true *$"')
        if empty(config)
          let worktree_for_dir[dir] = 0
        endif
      endif
    endif
    if exists('worktree')
      let worktree_for_dir[dir] = ghostgit#util#Slash(resolve(worktree))
      let dir_for_worktree[worktree_for_dir[dir]] = dir
    endif
  endif
  if worktree_for_dir[dir] =~# '^\.'
    return simplify(dir . '/' . worktree_for_dir[dir])
  else
    return worktree_for_dir[dir]
  endif
endfunction

" ── Actual dir (resolved git dir) ───────────────────────────────────

function! ghostgit#core#ActualDir(...) abort
  let dir = call('ghostgit#core#GitDir', a:000)
  if empty(dir)
    return ''
  endif
  let resolved_git_dirs = ghostgit#state#GetResolvedGitDirs()
  if !has_key(resolved_git_dirs, dir)
    let resolved_git_dirs[dir] = ghostgit#core#ResolveGitDir(dir)
  endif
  return empty(resolved_git_dirs[dir]) ? dir : resolved_git_dirs[dir]
endfunction

" ── Common dir (was FugitiveCommonDir) ──────────────────────────────

function! ghostgit#core#CommonDir(...) abort
  let dir = ghostgit#core#ActualDir(a:0 ? a:1 : -1)
  if empty(dir)
    return ''
  endif
  let commondirs = ghostgit#state#GetCommonDirs()
  if has_key(commondirs, dir)
    return commondirs[dir]
  endif
  if getfsize(dir . '/HEAD') >= 10
    let cdir = get(s:read_file(dir . '/commondir', 1), 0, '')
    if cdir =~# '^/\|^\a:/'
      let commondirs[dir] = ghostgit#util#Slash(ghostgit#util#VimPath(cdir))
    elseif len(cdir)
      let commondirs[dir] = simplify(dir . '/' . cdir)
    else
      let commondirs[dir] = dir
    endif
  else
    let commondirs[dir] = dir
  endif
  return commondirs[dir]
endfunction

" ── Work tree (was FugitiveWorkTree) ────────────────────────────────

function! ghostgit#core#WorkTree(...) abort
  let tree = s:tree(ghostgit#core#GitDir(a:0 ? a:1 : -1))
  if tree isnot# 0 || a:0 > 1
    return tree
  else
    return ''
  endif
endfunction

" ── Ceiling directories ─────────────────────────────────────────────

function! s:ceiling_directories() abort
  return ghostgit#state#GetCeilingDirectories()
endfunction

" ── Extract git dir from path (was FugitiveExtractGitDir) ───────────

function! ghostgit#core#ExtractGitDir(path) abort
  if type(a:path) ==# type({})
    return get(a:path, 'ghostgit_dir', get(a:path, 'git_dir', ''))
  elseif type(a:path) == type(0)
    let path = ghostgit#util#Slash(a:path > 0 ? bufname(a:path) : bufname(''))
    if getbufvar(a:path, '&filetype') ==# 'netrw'
      let path = ghostgit#util#Slash(getbufvar(a:path, 'netrw_curdir', path))
    endif
  else
    let path = ghostgit#util#Slash(a:path)
  endif
  if path =~# '^ghostgit://'
    return ghostgit#core#Parse(path)[1]
  elseif empty(path)
    return ''
  endif
  let pre = substitute(matchstr(path, '^\a\a\+\ze:'), '^.', '\u&', '')
  if len(pre) && pre !=? 'ghostgit' && exists('*' . pre . 'Real')
    let path = {pre}Real(path)
  endif
  let root = ghostgit#util#Slash(fnamemodify(path, ':p:h'))
  let previous = ""
  let env_git_dir = len($GIT_DIR) ? ghostgit#util#Slash(simplify(fnamemodify(ghostgit#util#VimPath($GIT_DIR), ':p:s?[\/]$??'))) : ''
  call s:tree(env_git_dir)
  let ceiling_directories = s:ceiling_directories()
  while root !=# previous && root !~# '^$\|^//[^/]*$'
    if index(ceiling_directories, root) >= 0
      break
    endif
    if root ==# $GIT_WORK_TREE && ghostgit#core#IsGitDir(env_git_dir)
      return env_git_dir
    endif
    let dir_for_worktree = ghostgit#state#GetDirForWorktree()
    if has_key(dir_for_worktree, root)
      return dir_for_worktree[root]
    endif
    let dir = substitute(root, '[\/]$', '', '') . '/.git'
    let resolved = ghostgit#core#ResolveGitDir(dir)
    if !empty(resolved)
      let resolved_git_dirs = ghostgit#state#GetResolvedGitDirs()
      let resolved_git_dirs[dir] = resolved
      return dir is# resolved || s:tree(resolved) is# 0 ? dir : resolved
    elseif ghostgit#core#IsGitDir(root)
      let resolved_git_dirs = ghostgit#state#GetResolvedGitDirs()
      let resolved_git_dirs[root] = root
      return root
    endif
    let previous = root
    let root = fnamemodify(root, ':h')
  endwhile
  return ''
endfunction

" ── Detect git dir for buffer (was FugitiveDetect) ──────────────────

function! ghostgit#core#Detect(...) abort
  if v:version < 704
    return ''
  endif
  if exists('b:git_dir') && b:git_dir =~# '^$\|' . s:bad_git_dir
    unlet b:git_dir
  endif
  if !exists('b:git_dir')
    let b:git_dir = ghostgit#core#ExtractGitDir(a:0 ? a:1 : bufnr(''))
  endif
  return ''
endfunction

" ── Git path normalization ──────────────────────────────────────────

function! ghostgit#core#GitPath(path) abort
  return ghostgit#util#Slash(a:path)
endfunction

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

" ── Dir / Tree helpers ──────────────────────────────────────────────

function! ghostgit#core#Dir(...) abort
  return a:0 ? ghostgit#core#GitDir(a:1) : ghostgit#core#GitDir()
endfunction

function! ghostgit#core#GetTree(...) abort
  return a:0 ? ghostgit#core#WorkTree(a:1) : ghostgit#core#WorkTree()
endfunction

function! ghostgit#core#SameRepo(one, two) abort
  let one = ghostgit#core#GitDir(a:one)
  return !empty(one) && one ==# ghostgit#core#GitDir(a:two)
endfunction

" ── Initialize buffer with git dir ──────────────────────────────────

function! ghostgit#core#InitializeBuffer(repo) abort
  let b:git_dir = ghostgit#core#GitDir(a:repo)
endfunction

" ── Dir check ───────────────────────────────────────────────────────

let s:worktree_error = "core.worktree is required when using an external Git dir"

function! ghostgit#core#DirCheck(...) abort
  let dir = call('ghostgit#core#GitDir', a:000)
  if !empty(dir) && ghostgit#core#WorkTree(dir, 1) is# 0
    return 'return ' . string('echoerr "ghostgit: ' . s:worktree_error . '"')
  elseif !empty(dir)
    return ''
  elseif empty(bufname(''))
    return 'return ' . string('echoerr "ghostgit: working directory does not belong to a Git repository"')
  else
    return 'return ' . string('echoerr "ghostgit: file does not belong to a Git repository"')
  endif
endfunction

" ── Has option check ────────────────────────────────────────────────

function! ghostgit#core#HasOpt(args, ...) abort
  let args = a:args[0 : index(a:args, '--')]
  let opts = copy(a:000)
  if type(opts[0]) == type([])
    if empty(args) || index(opts[0], args[0]) == -1
      return 0
    endif
    call remove(opts, 0)
  endif
  for opt in opts
    if index(args, opt) != -1
      return 1
    endif
  endfor
endfunction

" ── Version check ───────────────────────────────────────────────────

function! ghostgit#core#VersionCheck() abort
  if v:version < 704
    return 'return ' . string('echoerr "ghostgit: Vim 7.4 or newer required"')
  elseif empty(ghostgit#git#GitVersion())
    let exe = get(ghostgit#git#GitCmd(), 0, '')
    if len(exe) && !executable(exe)
      return 'return ' . string('echoerr "ghostgit: cannot find ' . string(exe) . ' in PATH"')
    endif
    return 'return ' . string('echoerr "ghostgit: cannot execute Git"')
  elseif !ghostgit#git#GitVersion(1, 8, 5)
    return 'return ' . string('echoerr "ghostgit: Git 1.8.5 or newer required"')
  else
    if exists('b:git_dir') && empty(b:git_dir)
      unlet! b:git_dir
    endif
    return ''
  endif
endfunction

" ── Dir commit file parsing (was s:DirCommitFile) ───────────────────

if exists('+shellslash')
  let s:dir_commit_file = '\c^ghostgit://\%(/[^/]\@=\)\=\([^?#]\{-1,\}\)//\%(\(\x\{40,\}\|[0-3]\)\(/[^?#]*\)\=\)\=$'
else
  let s:dir_commit_file = '\c^ghostgit://\([^?#]\{-\}\)//\%(\(\x\{40,\}\|[0-3]\)\(/[^?#]*\)\=\)\=$'
endif

function! ghostgit#core#DirCommitFile(path) abort
  let vals = matchlist(ghostgit#util#Slash(a:path), s:dir_commit_file)
  if empty(vals)
    return ['', '', '']
  endif
  return [ghostgit#core#Dir(ghostgit#util#UrlDecode(vals[1])), vals[2], empty(vals[2]) ? '/.git/index' : ghostgit#util#UrlDecode(vals[3])]
endfunction

function! ghostgit#core#DirRev(url) abort
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  return [dir, commit . file ==# '/.git/index' ? ':' : (!empty(dir) && commit =~# '^.$' ? ':' : '') . commit . substitute(file, '^/', ':', '')]
endfunction

" ── Parse ghostgit:// URL ───────────────────────────────────────────

function! ghostgit#core#Parse(url) abort
  return reverse(ghostgit#core#DirRev(a:url))
endfunction

" ── Real path (was FugitiveReal / fugitive#Real) ────────────────────

function! ghostgit#core#Real(url) abort
  if empty(a:url)
    return ''
  endif
  let [dir, commit, file] = ghostgit#core#DirCommitFile(a:url)
  if len(dir)
    let tree = s:tree(dir)
    return ghostgit#util#VimSlash((len(tree) ? tree : ghostgit#core#GitDir(dir)) . file)
  endif
  let pre = substitute(matchstr(a:url, '^\a\a\+\ze:'), '^.', '\u&', '')
  if len(pre) && pre !=? 'ghostgit' && exists('*' . pre . 'Real')
    let url = {pre}Real(a:url)
  else
    let url = fnamemodify(a:url, ':p' . (a:url =~# '[\/]$' ? '' : ':s?[\/]$??'))
  endif
  return ghostgit#util#VimSlash(empty(url) ? a:url : url)
endfunction

" ── Path resolution (was FugitivePath) ──────────────────────────────

function! ghostgit#core#Path(url, ...) abort
  if empty(a:url)
    return ''
  endif
  let repo = a:0 > 1 ? ghostgit#core#Dir(a:2) : ghostgit#core#Dir()
  let tree = ghostgit#core#GetTree(repo)
  if !a:0
    return ghostgit#core#Real(a:url)
  elseif a:1 =~# '\.$'
    let path = ghostgit#util#Slash(ghostgit#core#Real(a:url))
    let cwd = getcwd()
    let lead = ''
    while ghostgit#util#Cpath(tree . '/', (cwd . '/')[0 : len(tree)])
      if ghostgit#util#Cpath(cwd . '/', path[0 : len(cwd)])
        if strpart(path, len(cwd) + 1) =~# '^\.git\%(/\|$\)'
          let lead .= '../'
        else
          return lead . strpart(path, len(cwd) + 1)
        endif
      endif
      let lead .= '../'
      let cwd = fnamemodify(cwd, ':h')
    endwhile
    return path
  elseif a:1 =~# '^:\%(\d\|$(\)\=$'
    let path = ghostgit#util#Slash(ghostgit#core#Real(a:url))
    return strpart(path, len(tree) + 1)
  elseif a:1 =~# '^/'
    let path = ghostgit#util#Slash(ghostgit#core#Real(a:url))
    if ghostgit#util#Cpath(tree . '/', path[0 : len(tree)])
      return a:1 . strpart(path, len(tree) + 1)
    endif
    return path
  else
    return ghostgit#core#Real(a:url)
  endif
endfunction

" ── Find object (was FugitiveFind) ──────────────────────────────────

function! ghostgit#core#Find(...) abort
  if a:0 && (type(a:1) ==# type({}) || type(a:1) ==# type(0))
    return call('ghostgit#buffer#Find', a:000[1:-1] + [ghostgit#core#GitDir(a:1)])
  else
    return ghostgit#buffer#Find(a:0 ? a:1 : bufnr(''), ghostgit#core#GitDir(a:0 > 1 ? a:2 : -1))
  endif
endfunction

" ── Git index file env ──────────────────────────────────────────────

function! ghostgit#core#GitIndexFileEnv() abort
  let git_index_file_env = ghostgit#state#Get('git_index_file_env', {})
  if $GIT_INDEX_FILE =~# '^/\|^\a:' && !has_key(git_index_file_env, $GIT_INDEX_FILE)
    let git_index_file_env[$GIT_INDEX_FILE] = ghostgit#util#Slash(ghostgit#util#VimPath($GIT_INDEX_FILE))
  endif
  return get(git_index_file_env, $GIT_INDEX_FILE, '')
endfunction

function! ghostgit#core#PrepareEnv(env, dir) abort
  if len($GIT_INDEX_FILE) && len(ghostgit#core#GetTree(a:dir)) && !has_key(a:env, 'GIT_INDEX_FILE')
    let index_dir = substitute(ghostgit#core#GitIndexFileEnv(), '[^/]\+$', '', '')
    let our_dir = ghostgit#buffer#Find('.git/', a:dir)
    if !ghostgit#util#Cpath(index_dir, our_dir) && !ghostgit#util#Cpath(resolve(index_dir), our_dir)
      let a:env['GIT_INDEX_FILE'] = ghostgit#core#GitPath(ghostgit#buffer#Find('.git/index', a:dir))
    endif
  endif
  if len($GIT_WORK_TREE)
    let a:env['GIT_WORK_TREE'] = '.'
  endif
endfunction
