" autoload/ghostgit/job.vim — Async jobs, channels, stderr/stdout, job queue
" Migrated from autoload/fugitive.vim (lines 336–450, 760–824, 3418–3620)

" ── Job support flag ────────────────────────────────────────────────

let s:run_jobs = (exists('*ch_close_in') || exists('*jobstart')) && exists('*bufwinid')

" ── Wait for jobs ───────────────────────────────────────────────────

function! ghostgit#job#Wait(job_or_jobs, ...) abort
  let original = type(a:job_or_jobs) == type([]) ? copy(a:job_or_jobs) : [a:job_or_jobs]
  let jobs = map(copy(original), 'type(v:val) ==# type({}) ? get(v:val, "job", "") : v:val')
  call filter(jobs, 'type(v:val) !=# type("")')
  let timeout_ms = a:0 ? a:1 : -1
  if exists('*jobwait')
    call map(copy(jobs), 'chanclose(v:val, "stdin")')
    call jobwait(jobs, timeout_ms)
    let jobs = map(copy(original), 'type(v:val) ==# type({}) ? get(v:val, "job", "") : v:val')
    call filter(jobs, 'type(v:val) !=# type("")')
    if len(jobs)
      sleep 1m
    endif
  else
    for job in jobs
      if ch_status(job) ==# 'open'
        call ch_close_in(job)
      endif
    endfor
    let i = 0
    for job in jobs
      while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
        if i == timeout_ms
          break
        endif
        let i += 1
        sleep 1m
      endwhile
    endfor
  endif
  return a:job_or_jobs
endfunction

" ── Job opts ────────────────────────────────────────────────────────

function! ghostgit#job#JobOptsInternal(cmd, env) abort
  if empty(a:env)
    return [a:cmd, {}]
  elseif has('patch-8.2.0239') ||
        \ has('nvim') && api_info().version.api_level - api_info().version.api_prerelease >= 7 ||
        \ has('patch-8.0.0902') && !has('nvim') && (!has('win32') || empty(filter(keys(a:env), 'exists("$" . v:val)')))
    return [a:cmd, {'env': a:env}]
  endif
  let envlist = map(items(a:env), 'join(v:val, "=")')
  if !has('win32')
    return [['/usr/bin/env'] + envlist + a:cmd, {}]
  else
    let pre = join(map(envlist, '"set " . substitute(v:val, "[&|<>^]", "^^^&", "g") . "& "'), '')
    if len(a:cmd) == 3 && a:cmd[0] ==# 'cmd.exe' && a:cmd[1] ==# '/c'
      return [a:cmd[0:1] + [pre . a:cmd[2]], {}]
    else
      return [['cmd.exe', '/c', pre . ghostgit#util#WinShellEsc(a:cmd)], {}]
    endif
  endif
endfunction

" ── Prepare job ─────────────────────────────────────────────────────

function! ghostgit#job#PrepareJobInternal(opts) abort
  let dict = {'argv': a:opts.argv}
  if has_key(a:opts, 'env')
    let dict.env = a:opts.env
  endif
  let [argv, jopts] = ghostgit#job#JobOptsInternal(a:opts.argv, get(a:opts, 'env', {}))
  if has_key(a:opts, 'cwd')
    if has('patch-8.0.0902')
      let jopts.cwd = a:opts.cwd
      let dict.cwd = a:opts.cwd
    else
      throw 'ghostgit: cwd unsupported'
    endif
  endif
  return [argv, jopts, dict]
endfunction

" ── Job execute ─────────────────────────────────────────────────────

function! ghostgit#job#JobExecute(argv, jopts, stdin, callback, ...) abort
  let dict = a:0 ? a:1 : {}
  let cb = len(a:callback) ? a:callback : [function('len')]
  if exists('*jobstart')
    call extend(a:jopts, {
          \ 'stdout_buffered': v:true,
          \ 'stderr_buffered': v:true,
          \ 'on_exit': function('s:job_nvim_exit', [dict, cb])})
    try
      let dict.job = jobstart(a:argv, a:jopts)
      if !empty(a:stdin)
        call chansend(dict.job, a:stdin)
      endif
      call chanclose(dict.job, 'stdin')
    catch /^Vim\%((\a\+)\)\=:E475:/
      let [dict.exit_status, dict.stdout, dict.stderr] = [122, [''], ['']]
    endtry
  elseif exists('*ch_close_in')
    let temp = tempname()
    call extend(a:jopts, {
          \ 'out_io': 'file',
          \ 'out_name': temp . '.out',
          \ 'err_io': 'file',
          \ 'err_name': temp . '.err',
          \ 'exit_cb': function('s:job_vim_exit', [dict, cb, temp])})
    if a:stdin ==# ['']
      let a:jopts.in_io = 'null'
    elseif !empty(a:stdin)
      let a:jopts.in_io = 'file'
      let a:jopts.in_name = temp . '.in'
      call writefile(a:stdin, a:jopts.in_name, 'b')
    endif
    let dict.job = job_start(a:argv, a:jopts)
    if job_status(dict.job) ==# 'fail'
      let [dict.exit_status, dict.stdout, dict.stderr] = [122, [''], ['']]
      unlet dict.job
    endif
  elseif &shell !~# 'sh' || &shell =~# 'fish\|\%(powershell\|pwsh\)\%(\.exe\)\=$'
    throw 'ghostgit: Vim 8 or higher required to use ' . &shell
  else
    let cmd = ghostgit#util#ShellEsc(a:argv)
    let outfile = tempname()
    try
      if len(a:stdin)
        call writefile(a:stdin, outfile . '.in', 'b')
        let cmd = ' (' . cmd . ' >' . outfile . ' <' . outfile . '.in) '
      else
        let cmd = ' (' . cmd . ' >' . outfile . ') '
      endif
      let dict.stderr = split(system(cmd), "\n", 1)
      let dict.exit_status = v:shell_error
      let dict.stdout = readfile(outfile, 'b')
      call call(cb[0], [dict] + cb[1:-1])
    finally
      call delete(outfile)
      call delete(outfile . '.in')
    endtry
  endif
  if empty(a:callback)
    call ghostgit#job#Wait(dict)
  endif
  return dict
endfunction

" ── Job exit callbacks ──────────────────────────────────────────────

function! s:job_vim_exit(dict, callback, temp, job, status) abort
  let a:dict.exit_status = a:status
  let a:dict.stderr = readfile(a:temp . '.err', 'b')
  call delete(a:temp . '.err')
  let a:dict.stdout = readfile(a:temp . '.out', 'b')
  call delete(a:temp . '.out')
  call delete(a:temp . '.in')
  call remove(a:dict, 'job')
  call call(a:callback[0], [a:dict] + a:callback[1:-1])
endfunction

function! s:job_nvim_exit(dict, callback, job, data, type) dict abort
  let a:dict.stdout = self.stdout
  let a:dict.stderr = self.stderr
  let a:dict.exit_status = a:data
  call remove(a:dict, 'job')
  call call(a:callback[0], [a:dict] + a:callback[1:-1])
endfunction

" ── Temp state registry ─────────────────────────────────────────────

function! ghostgit#job#SaveState(state) abort
  call ghostgit#state#SetTempState(a:state.file, a:state)
endfunction

function! ghostgit#job#TempState(...) abort
  return ghostgit#state#GetTempState(a:0 ? a:1 : -1)
endfunction

" ── Result accessor ─────────────────────────────────────────────────

function! ghostgit#job#Result(...) abort
  if !a:0 && exists('g:ghostgit_event')
    return ghostgit#state#GetEventResult()
  elseif !a:0 || type(a:1) == type('') && a:1 =~# '^-\=$'
    return ghostgit#state#GetLastJob()
  elseif type(a:1) == type(0)
    return ghostgit#job#TempState(a:1)
  elseif type(a:1) == type('')
    return ghostgit#job#TempState(a:1)
  elseif type(a:1) == type({}) && has_key(a:1, 'file')
    return ghostgit#job#TempState(a:1.file)
  else
    return {}
  endif
endfunction

" ── Run finished ────────────────────────────────────────────────────

function! ghostgit#job#RunFinished(state) abort
  let last_job = ghostgit#state#GetLastJob()
  if has_key(last_job, 'file') && bufnr(last_job.file) < 0
    call ghostgit#state#ClearTempState(last_job.file)
    call ghostgit#state#Unset('_ghostgit_last_job')
  endif
  call ghostgit#state#SetLastJob(a:state)
  let first = join(readfile(a:state.file, '', 2), "\n")
  if get(a:state, 'filetype', '') ==# 'git' && first =~# '\<\([[:upper:][:digit:]_-]\+(\d\+)\).*\1'
    let a:state.filetype = 'man'
  endif
endfunction

" ── PTY / Pager ─────────────────────────────────────────────────────

function! ghostgit#job#CanPty() abort
  return get(g:, 'ghostgit_pty',
        \ has('nvim') && exists('*nvim_open_term') && (has('unix') || has('win32')) &&
        \ !has('win32unix') && (!has('win32') || !s:winshell()))
endfunction

function! ghostgit#job#PagerFor(argv, ...) abort
  let cmd = get(a:argv, 0, '')
  let dir = a:0 ? a:1 : ghostgit#core#GitDir()
  if cmd =~# '^\%(help\|config\)'
    return 1
  elseif cmd ==# 'log' || cmd ==# 'diff' || cmd ==# 'show'
    return !ghostgit#util#IsExecutable('less') || get(ghostgit#config#GetAll('core.pager', dir), 0, '') ==# ''
  endif
  return 0
endfunction

" ── Resume after job ────────────────────────────────────────────────

function! ghostgit#job#Resume() abort
  if exists('s:resume_state')
    let state = s:resume_state
    unlet s:resume_state
    if has_key(state, 'file')
      exe 'keepalt edit' ghostgit#util#FnameEscape(state.file)
    endif
  endif
  return ''
endfunction
