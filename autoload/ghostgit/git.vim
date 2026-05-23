" autoload/ghostgit/git.vim — Git command wrappers, shell escaping, git execution
" Migrated from autoload/fugitive.vim Section: Git (lines 458–1048)

" ── Git binary detection ────────────────────────────────────────────

function! ghostgit#git#GitCmd() abort
  if !exists('g:ghostgit_git_executable')
    return ['git']
  elseif type(g:ghostgit_git_executable) == type([])
    return g:ghostgit_git_executable
  elseif !empty(s:git_cmd_cache) && s:git_cmd_cache[0] is# g:ghostgit_git_executable
    return s:git_cmd_cache[1]
  endif
  let dquote = '"\%([^"]\|""\|\\"\)*"\|'
  let string = g:ghostgit_git_executable
  let list = []
  if string =~# '^\w\+='
    call add(list, '/usr/bin/env')
  endif
  while string =~# '\S'
    let arg = matchstr(string, '^\s*\%(' . dquote . '''[^'']*''\|\\.\|[^' . "\t" . ' |]\)\+')
    let string = strpart(string, len(arg))
    let arg = substitute(arg, '^\s\+', '', '')
    let arg = substitute(arg,
          \ '\(' . dquote . '''\%(''''\|[^'']\)*''\|\\[' . s:fnameescape . ']\|^\\[>+-]\|' . s:commit_expand . '\)\|' . s:expand,
          \ '\=submatch(0)[0] ==# "\\" ? submatch(0)[1] : submatch(0)[1:-2]', 'g')
    call add(list, arg)
  endwhile
  let s:git_cmd_cache = [g:ghostgit_git_executable, list]
  return list
endfunction

function! ghostgit#git#GitShellCmd() abort
  if !exists('g:ghostgit_git_executable')
    return 'git'
  elseif type(g:ghostgit_git_executable) == type([])
    return ghostgit#util#ShellEsc(g:ghostgit_git_executable)
  else
    return g:ghostgit_git_executable
  endif
endfunction

" ── Constants for arg parsing ───────────────────────────────────────

let s:fnameescape = "\t \"|'`$\\<>~^*?[](){}&;"
let s:var = '\%(<\%(cword\|cWORD\|cexpr\|cfile\|sfile\|slnum\|afile\|abuf\|amatch' . (has('clientserver') ? '\|client' : '') . '\)>\|%\|#<\=\d\+\|##\=\)'
let s:flag = '\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)'
let s:expand = '\%(\(' . s:var . '\)\(' . s:flag . '*\)\(:S\)\=\)'
let s:commit_expand = '!\\\@!#\=\d*\|!%'

let s:git_cmd_cache = []

" ── User command list ───────────────────────────────────────────────

function! ghostgit#git#UserCommandCwd(dir) abort
  let tree = ghostgit#core#WorkTree(a:dir)
  return len(tree) ? ghostgit#util#VimSlash(tree) : getcwd()
endfunction

function! ghostgit#git#UserCommandList(...) abort
  if !ghostgit#git#GitVersion(1, 8, 5)
    throw 'ghostgit: Git 1.8.5 or higher required'
  endif
  if !exists('g:ghostgit_git_command')
    let git = ghostgit#git#GitCmd()
  elseif type(g:ghostgit_git_command) == type([])
    let git = g:ghostgit_git_command
  else
    let git = split(g:ghostgit_git_command, '\s\+')
  endif
  let flags = []
  if a:0 && type(a:1) == type({})
    let git = copy(get(a:1, 'git', git))
    let flags = get(a:1, 'flags', flags)
    let dir = a:1.git_dir
  elseif a:0
    let dir = ghostgit#core#GitDir(a:1)
  else
    let dir = ''
  endif
  if len(dir)
    let tree = ghostgit#core#WorkTree(dir)
    if empty(tree)
      call add(git, '--git-dir=' . ghostgit#core#GitPath(dir))
    else
      if !ghostgit#util#Cpath(tree . '/.git', dir) || len($GIT_DIR)
        call add(git, '--git-dir=' . ghostgit#core#GitPath(dir))
      endif
      if !ghostgit#util#Cpath(tree, getcwd())
        call extend(git, ['-C', ghostgit#core#GitPath(tree)])
      endif
    endif
  endif
  return git + flags
endfunction

" ── Git version ─────────────────────────────────────────────────────

function! ghostgit#git#GitVersion(...) abort
  let git = ghostgit#git#GitShellCmd()
  let git_versions = ghostgit#state#GetGitVersions()
  if !has_key(git_versions, git)
    let git_versions[git] = matchstr(get(ghostgit#job#Execute(ghostgit#git#GitCmd() + ['--version'], {}, [], []).stdout, 0, ''), '\d[^[:space:]]\+')
  endif
  if !a:0
    return git_versions[git]
  endif
  let components = split(git_versions[git], '\D\+')
  if empty(components)
    return -1
  endif
  for i in range(len(a:000))
    if a:000[i] > +get(components, i)
      return 0
    elseif a:000[i] < +get(components, i)
      return 1
    endif
  endfor
  return 1
endfunction

" ── Head (branch name) ──────────────────────────────────────────────

function! ghostgit#git#Head(...) abort
  let dir = a:0 > 1 ? a:2 : ghostgit#core#GitDir()
  if empty(dir)
    return ''
  endif
  let file = ghostgit#core#ActualDir(dir) . '/HEAD'
  let ftime = getftime(file)
  let head_cache = ghostgit#state#GetHeadCache()
  if ftime == -1
    return ''
  elseif ftime != get(head_cache, file, [-1])[0]
    let head_cache[file] = [ftime, readfile(file)[0]]
  endif
  let head = head_cache[file][1]
  let len = a:0 ? a:1 : 0
  if head =~# '^ref: '
    if len < 0
      return strpart(head, 5)
    else
      return substitute(head, '\C^ref: \%(refs/\%(heads/\|remotes/\|tags/\)\=\)\=', '', '')
    endif
  elseif head =~# '^\x\{40,\}$'
    return len < 0 ? head : strpart(head, 0, len)
  else
    return ''
  endif
endfunction

" ── Rev parse ───────────────────────────────────────────────────────

function! ghostgit#git#RevParse(rev, ...) abort
  let hash = ghostgit#git#ChompDefault('', [a:0 ? a:1 : ghostgit#core#GitDir(), 'rev-parse', '--verify', a:rev, '--'])
  if hash =~# '^\x\{40,\}$'
    return hash
  endif
  throw 'ghostgit: failed to parse revision ' . a:rev
endfunction

" ── Shell command builder ───────────────────────────────────────────

function! ghostgit#git#ShellCommand(...) abort
  let [repo, _, env, git, flags, args] = call('ghostgit#git#PrepareDirEnvGitFlagsArgs', a:000)
  return s:build_shell(ghostgit#core#GitDir(repo), env, git, flags + args)
endfunction

" ── Prepare job ─────────────────────────────────────────────────────

function! ghostgit#git#PrepareJob(...) abort
  if a:0 == 1 && type(a:1) == type({}) && has_key(a:1, 'argv') && !has_key(a:1, 'args')
    return ghostgit#job#PrepareJobInternal(a:1)
  endif
  let [repo, user_env, exec_env, git, flags, args] = call('ghostgit#git#PrepareDirEnvGitFlagsArgs', a:000)
  let dir = ghostgit#core#GitDir(repo)
  let dict = {'git': git, 'git_dir': dir, 'flags': flags, 'args': args}
  if len(user_env)
    let dict.env = user_env
  endif
  let cmd = flags + args
  let tree = ghostgit#core#WorkTree(repo)
  if empty(tree) || index(cmd, '--') == len(cmd) - 1
    let dict.cwd = getcwd()
    call extend(cmd, ['--git-dir=' . ghostgit#core#GitPath(dir)], 'keep')
  else
    let dict.cwd = ghostgit#util#VimSlash(tree)
    call extend(cmd, ['-C', ghostgit#core#GitPath(tree)], 'keep')
    if !ghostgit#util#Cpath(tree . '/.git', dir) || len($GIT_DIR)
      call extend(cmd, ['--git-dir=' . ghostgit#core#GitPath(dir)], 'keep')
    endif
  endif
  call extend(cmd, git, 'keep')
  return ghostgit#job#JobOptsInternal(cmd, exec_env) + [dict]
endfunction

" ── Execute ─────────────────────────────────────────────────────────

function! ghostgit#git#Execute(...) abort
  let cb = copy(a:000)
  let cmd = []
  let stdin = []
  while len(cb) && type(cb[0]) !=# type(function('tr'))
    if type(cb[0]) ==# type({}) && has_key(cb[0], 'stdin')
      if type(cb[0].stdin) == type([])
        call extend(stdin, cb[0].stdin)
      elseif type(cb[0].stdin) == type('')
        call extend(stdin, readfile(cb[0].stdin, 'b'))
      endif
      if len(keys(cb[0])) == 1
        call remove(cb, 0)
        continue
      endif
    endif
    call add(cmd, remove(cb, 0))
  endwhile
  let [argv, jopts, dict] = call('ghostgit#git#PrepareJob', cmd)
  return ghostgit#job#JobExecute(argv, jopts, stdin, cb, dict)
endfunction

" ── Internal helpers ────────────────────────────────────────────────

function! s:build_shell(dir, env, git, args) abort
  let cmd = copy(a:args)  " Copy to avoid mutating caller's list (insert/extend below)
  let tree = ghostgit#core#WorkTree(a:dir)
  let pre = s:build_env_prefix(a:env)
  if empty(tree) || index(cmd, '--') == len(cmd) - 1
    call insert(cmd, '--git-dir=' . ghostgit#core#GitPath(a:dir))
  else
    call extend(cmd, ['-C', ghostgit#core#GitPath(tree)], 'keep')
    if !ghostgit#util#Cpath(tree . '/.git', a:dir) || len($GIT_DIR)
      call extend(cmd, ['--git-dir=' . ghostgit#core#GitPath(a:dir)], 'keep')
    endif
  endif
  return pre . join(map(a:git + cmd, 'ghostgit#util#ShellEsc(v:val)'))
endfunction

function! s:build_env_prefix(env) abort
  let pre = ''
  let env = items(a:env)
  if empty(env)
    return ''
  elseif &shell =~# '\%(powershell\|pwsh\)\%(\.exe\)\=$'
    return join(map(env, '"$Env:" . v:val[0] . " = ''" . substitute(v:val[1], "''", "''''", "g") . "''; "'), '')
  elseif ghostgit#util#WinShell()
    return join(map(env, '"set " . substitute(join(v:val, "="), "[&|<>^]", "^^^&", "g") . "& "'), '')
  else
    return '/usr/bin/env ' . ghostgit#util#ShellEsc(map(env, 'join(v:val, "=")')) . ' '
  endif
endfunction

" ── System helpers ──────────────────────────────────────────────────

function! ghostgit#git#SystemList(cmd) abort
  let exit = []
  if exists('*jobstart')
    let lines = ['']
    let jopts = {
          \ 'on_stdout': function('s:job_nvim_callback', [lines]),
          \ 'on_stderr': function('s:job_nvim_callback', [lines]),
          \ 'on_exit': { j, code, _ -> add(exit, code) }}
    let job = jobstart(a:cmd, jopts)
    call chanclose(job, 'stdin')
    call jobwait([job])
    if empty(lines[-1])
      call remove(lines, -1)
    endif
    return [lines, exit[0]]
  elseif exists('*ch_close_in')
    let lines = []
    let jopts = {
          \ 'out_cb': { j, str -> add(lines, str) },
          \ 'err_cb': { j, str -> add(lines, str) },
          \ 'exit_cb': { j, code -> add(exit, code) }}
    let job = job_start(a:cmd, jopts)
    call ch_close_in(job)
    while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
      sleep 1m
    endwhile
    return [lines, exit[0]]
  else
    let [output, exec_error] = s:system_error(ghostgit#util#ShellEsc(a:cmd))
    let lines = split(output, "\n", 1)
    if empty(lines[-1])
      call remove(lines, -1)
    endif
    return [lines, v:shell_error]
  endif
endfunction

function! s:job_nvim_callback(lines, job, data, type) abort
  let a:lines[-1] .= remove(a:data, 0)
  call extend(a:lines, a:data)
endfunction

function! s:system_error(cmd, ...) abort
  let cmd = type(a:cmd) == type([]) ? ghostgit#util#ShellEsc(a:cmd) : a:cmd
  try
    if &shellredir ==# '>' && &shell =~# 'sh\|cmd'
      let shellredir = &shellredir
      if &shell =~# 'csh'
        set shellredir=>&
      else
        set shellredir=>%s\ 2>&1
      endif
    endif
    if exists('+guioptions') && &guioptions =~# '!'
      let guioptions = &guioptions
      set guioptions-=!
    endif
    let out = call('system', [cmd] + a:000)
    return [out, v:shell_error]
  catch /^Vim\%((\a\+)\)\=:E484:/
    let opts = ['shell', 'shellcmdflag', 'shellredir', 'shellquote', 'shellxquote', 'shellxescape', 'shellslash']
    call filter(opts, 'exists("+".v:val) && !empty(eval("&".v:val))')
    call map(opts, 'v:val."=".eval("&".v:val)')
    call ghostgit#util#Throw('failed to run `' . cmd . '` with ' . join(opts, ' '))
  finally
    if exists('shellredir')
      let &shellredir = shellredir
    endif
    if exists('guioptions')
      let &guioptions = guioptions
    endif
  endtry
endfunction

" ── Chomp helpers ───────────────────────────────────────────────────

function! ghostgit#git#ChompStderr(...) abort
  let r = call('ghostgit#git#Execute', a:000)
  return join(get(r, 'stderr', []), "\n")
endfunction

function! ghostgit#git#ChompDefault(default, ...) abort
  let r = call('ghostgit#git#Execute', a:000[1:-1])
  return r.exit_status ? a:default : get(r.stdout, 0, '')
endfunction

function! ghostgit#git#LinesError(...) abort
  let r = call('ghostgit#git#Execute', a:000)
  let lines = split(tr(join(get(r, 'stdout', []), "\1"), "\1\n", "\n\1"), "\1", 1)[0:-2]
  return [lines, r.exit_status]
endfunction

function! ghostgit#git#TreeChomp(...) abort
  let r = call('ghostgit#git#Execute', a:000)
  if r.exit_status
    throw 'ghostgit: ' . s:join_chomp(get(r, 'stderr', []))
  endif
  return get(r.stdout, 0, '')
endfunction

function! s:join_chomp(list) abort
  if empty(a:list[-1])
    return join(a:list[0:-2], "\n")
  else
    return join(a:list, "\n")
  endif
endfunction

" ── Stdout to file ──────────────────────────────────────────────────

function! ghostgit#git#StdoutToFile(out, cmd, ...) abort
  let err = tempname()
  try
    if exists('*jobstart')
      let cmd = a:cmd
      let env = a:0 ? a:1 : {}
      let [cmd, jopts] = ghostgit#job#JobOptsInternal(cmd, env)
      let jopts.stdout = a:out
      let jopts.stderr = err
      let job = jobstart(cmd, jopts)
      call chanclose(job, 'stdin')
      call jobwait([job])
      return [join(readfile(err, 'b'), "\n"), 0]
    elseif exists('*ch_close_in')
      let cmd = a:cmd
      let env = a:0 ? a:1 : {}
      let [cmd, jopts] = ghostgit#job#JobOptsInternal(cmd, env)
      call extend(jopts, {
            \ 'out_io': 'file',
            \ 'out_name': a:out,
            \ 'err_io': 'file',
            \ 'err_name': err})
      let job = job_start(cmd, jopts)
      while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
        sleep 1m
      endwhile
      let exit = job_status(job) ==# 'fail' ? [122] : [0]
      return [join(readfile(err, 'b'), "\n"), exit[0]]
    elseif ghostgit#util#WinShell() || &shell !~# 'sh' || &shell =~# 'fish\|\%(powershell\|pwsh\)\%(\.exe\)\=$'
      throw 'ghostgit: Vim 8 or higher required to use ' . &shell
    else
      let cmd = ghostgit#git#ShellCommand(a:cmd)
      return call('s:system_error', [' (' . cmd . ' >' . (len(a:out) ? a:out : '/dev/null') . ') '] + a:000)
    endif
  finally
    call delete(err)
  endtry
endfunction

" ── Prepare dir/env/git/flags/args ──────────────────────────────────

let s:prepare_env = {
      \ 'GIT_DIR': 'git_dir',
      \ 'GIT_WORK_TREE': 'work_tree',
      \ 'GIT_INDEX_FILE': 'index_file',
      \ 'GIT_NAMESPACE': 'namespace',
      \ 'GIT_SSH': 'ssh',
      \ 'GIT_SSH_COMMAND': 'ssh_command',
      \ 'GIT_ASKPASS': 'askpass',
      \ 'GIT_TERMINAL_PROMPT': 'terminal_prompt'}

function! ghostgit#git#PrepareDirEnvGitFlagsArgs(...) abort
  let literal_pathspecs = 1
  let explicit_pathspec_option = 0
  let arg_count = 0
  let cmd = []
  let env = {}
  let git_dir = ''
  let i = 0
  while i < len(a:000)
    let arg = a:000[i]
    if type(arg) == type('') && arg =~# '^++'
      if arg =~# '^++novertical$' || arg =~# '^++curwin$' || arg =~# '^++no-.*$'
        let i += 1
        continue
      elseif arg =~# '^++git='
        let git = split(strpart(arg, 6), '\s\+')
        let i += 1
        continue
      elseif arg =~# '^++git$'
        let git = split(a:000[i+1], '\s\+')
        let i += 2
        continue
      endif
    elseif type(arg) == type('') && arg =~# '^[A-Z_]\+=.'
      let key = matchstr(arg, '^[A-Z_]\+=')[:-2]
      let val = strpart(arg, len(key) + 1)
      let env[key] = val
      let i += 1
      continue
    elseif type(arg) == type({}) && has_key(arg, 'env')
      call extend(env, arg.env)
      let i += 1
      continue
    elseif type(arg) == type(0)
      let arg_count += 1
    elseif arg ==# '--'
      let arg_count = len(a:000) - i - 1
      break
    endif
    call add(cmd, arg)
    let i += 1
  endwhile
  let dir = ghostgit#core#GitDir(len(git_dir) ? git_dir : (len(cmd) && type(cmd[0]) == type('') && cmd[0] =~# '^\%(\.\.\=\|/\|\a:\)' ? '' : -1))
  let autoenv = {}
  if len(dir) && len($GIT_DIR)
    let autoenv.GIT_DIR = ghostgit#core#GitPath(dir)
  endif
  if len($GPG_TTY) && !has_key(env, 'GPG_TTY')
    let autoenv.GPG_TTY = ''
  endif
  call s:prepare_path_args(cmd, dir, literal_pathspecs, explicit_pathspec_option)
  return [dir, env, extend(autoenv, env), ghostgit#git#GitCmd(), cmd[0 : -arg_count-1], arg_count ? cmd[-arg_count : -1] : []]
endfunction

function! s:resolve_integer_arg(cmd, i, literal, dir) abort
  if a:literal
    let a:cmd[a:i] = ghostgit#buffer#Path(bufname(a:cmd[a:i]), './', a:dir)
  else
    let a:cmd[a:i] = ghostgit#buffer#Path(bufname(a:cmd[a:i]), ':(top,literal)', a:dir)
  endif
endfunction

function! s:prepare_path_args(cmd, dir, literal, explicit) abort
  if !a:explicit
    call insert(a:cmd, '--literal-pathspecs')
  endif
  let split = index(a:cmd, '--')
  for i in range(split < 0 ? len(a:cmd) : split)
    if type(a:cmd[i]) == type(0)
      call s:resolve_integer_arg(a:cmd, i, a:literal, a:dir)
    endif
  endfor
  if split < 0
    return a:cmd
  endif
  for i in range(split + 1, len(a:cmd) - 1)
    if type(a:cmd[i]) == type(0)
      call s:resolve_integer_arg(a:cmd, i, a:literal, a:dir)
    elseif !a:explicit
      let a:cmd[i] = ghostgit#buffer#Path(a:cmd[i], './', a:dir)
    endif
  endfor
  return a:cmd
endfunction
