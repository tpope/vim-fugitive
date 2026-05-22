" autoload/ghostgit/state.vim — Shared runtime state, caches, session info
" Migrated from scattered s:* variables across autoload/fugitive.vim

" ── Internal storage ────────────────────────────────────────────────

let s:store = {}

" ── Generic accessors ───────────────────────────────────────────────

function! ghostgit#state#Get(key, default) abort
  return get(s:store, a:key, a:default)
endfunction

function! ghostgit#state#Set(key, value) abort
  let s:store[a:key] = a:value
endfunction

function! ghostgit#state#Has(key) abort
  return has_key(s:store, a:key)
endfunction

function! ghostgit#state#Unset(key) abort
  if has_key(s:store, a:key)
    unlet s:store[a:key]
  endif
endfunction

" ── Cache expiry ────────────────────────────────────────────────────

function! ghostgit#state#Expire(...) abort
  if !a:0
    let s:store = {}
    return
  endif
  for key in a:000
    if has_key(s:store, key)
      unlet s:store[key]
    endif
  endfor
endfunction

" ── Temp files registry (was s:temp_files) ──────────────────────────

function! ghostgit#state#GetTempState(...) abort
  let file = a:0 ? a:1 : -1
  let key = ghostgit#util#Cpath(ghostgit#util#AbsoluteVimPath(file))
  return get(s:store.temp_files, key, {})
endfunction

function! ghostgit#state#SetTempState(file, state) abort
  if !has_key(s:store, 'temp_files')
    let s:store.temp_files = {}
  endif
  let key = ghostgit#util#Cpath(ghostgit#util#AbsoluteVimPath(a:file))
  let s:store.temp_files[key] = a:state
endfunction

function! ghostgit#state#ClearTempState(file) abort
  if !has_key(s:store, 'temp_files')
    return
  endif
  let key = ghostgit#util#Cpath(ghostgit#util#AbsoluteVimPath(a:file))
  if has_key(s:store.temp_files, key)
    let last_job = get(g:, '_ghostgit_last_job', {})
    if has_key(last_job, 'file') && ghostgit#util#Cpath(last_job.file) ==# key
      return
    endif
    if !has_key(s:store.temp_files[key], 'job')
      call delete(a:file)
    endif
    call remove(s:store.temp_files, key)
  endif
endfunction

" ── Last job (was g:_fugitive_last_job) ─────────────────────────────

function! ghostgit#state#GetLastJob() abort
  return get(g:, '_ghostgit_last_job', {})
endfunction

function! ghostgit#state#SetLastJob(state) abort
  let g:_ghostgit_last_job = a:state
endfunction

" ── Event context (was g:fugitive_event / g:fugitive_result) ────────

function! ghostgit#state#GetEventDir() abort
  return get(g:, 'ghostgit_event', '')
endfunction

function! ghostgit#state#GetEventResult() abort
  return get(g:, 'ghostgit_result', {})
endfunction

function! ghostgit#state#SetEvent(dir, result) abort
  let g:ghostgit_event = a:dir
  if !empty(a:result)
    let g:ghostgit_result = a:result
  endif
endfunction

function! ghostgit#state#ClearEvent() abort
  unlet! g:ghostgit_event g:ghostgit_result
endfunction

" ── DidChange timestamp (was g:fugitive_did_change_at) ──────────────

function! ghostgit#state#GetDidChangeTime() abort
  return get(g:, 'ghostgit_did_change_at', reltime())
endfunction

function! ghostgit#state#SetDidChangeTime() abort
  let g:ghostgit_did_change_at = reltime()
endfunction

" ── HEAD cache (was s:head_cache) ──────────────────────────────────

function! ghostgit#state#GetHeadCache() abort
  if !has_key(s:store, 'head_cache')
    let s:store.head_cache = {}
  endif
  return s:store.head_cache
endfunction

function! ghostgit#state#ClearHeadCache() abort
  let s:store.head_cache = {}
endfunction

" ── Config cache (was s:config / s:config_prototype) ────────────────

function! ghostgit#state#GetConfigCache() abort
  if !has_key(s:store, 'config')
    let s:store.config = {}
  endif
  return s:store.config
endfunction

function! ghostgit#state#SetConfigCache(key, value) abort
  if !has_key(s:store, 'config')
    let s:store.config = {}
  endif
  let s:store.config[a:key] = a:value
endfunction

function! ghostgit#state#ClearConfigCache(...) abort
  if !a:0
    let s:store.config = {}
  elseif has_key(s:store, 'config')
    let key = a:1 is# '' ? '_' : a:1
    if has_key(s:store.config, key)
      call remove(s:store.config, key)
    endif
  endif
endfunction

function! ghostgit#state#GetConfigPrototype() abort
  if !has_key(s:store, 'config_prototype')
    let s:store.config_prototype = {}
  endif
  return s:store.config_prototype
endfunction

" ── Remote headers cache (was s:remote_headers) ─────────────────────

function! ghostgit#state#GetRemoteHeaders() abort
  if !has_key(s:store, 'remote_headers')
    let s:store.remote_headers = {}
  endif
  return s:store.remote_headers
endfunction

" ── Git version cache (was s:git_versions) ──────────────────────────

function! ghostgit#state#GetGitVersions() abort
  if !has_key(s:store, 'git_versions')
    let s:store.git_versions = {}
  endif
  return s:store.git_versions
endfunction

" ── Worktree cache (was s:worktree_for_dir / s:dir_for_worktree) ────

function! ghostgit#state#GetWorktreeForDir() abort
  if !has_key(s:store, 'worktree_for_dir')
    let s:store.worktree_for_dir = {}
  endif
  return s:store.worktree_for_dir
endfunction

function! ghostgit#state#GetDirForWorktree() abort
  if !has_key(s:store, 'dir_for_worktree')
    let s:store.dir_for_worktree = {}
  endif
  return s:store.dir_for_worktree
endfunction

" ── Common dirs cache (was s:commondirs) ────────────────────────────

function! ghostgit#state#GetCommonDirs() abort
  if !has_key(s:store, 'commondirs')
    let s:store.commondirs = {}
  endif
  return s:store.commondirs
endfunction

" ── Resolved git dirs (was s:resolved_git_dirs) ─────────────────────

function! ghostgit#state#GetResolvedGitDirs() abort
  if !has_key(s:store, 'resolved_git_dirs')
    let s:store.resolved_git_dirs = {}
  endif
  return s:store.resolved_git_dirs
endfunction

" ── Ceiling directories (was s:ceiling_directories) ─────────────────

function! ghostgit#state#GetCeilingDirectories() abort
  if !has_key(s:store, 'ceiling_directories')
    let s:store.ceiling_directories = []
    let resolve = 1
    for dir in split($GIT_CEILING_DIRECTORIES, has('win32') ? ';' : ':', 1)
      if empty(dir)
        let resolve = 0
      elseif resolve
        call add(s:store.ceiling_directories, ghostgit#util#VimSlash(resolve(dir)))
      else
        call add(s:store.ceiling_directories, ghostgit#util#VimSlash(dir))
      endif
    endfor
    call add(s:store.ceiling_directories, ghostgit#util#VimSlash(fnamemodify(expand('~'), ':h')))
  endif
  return s:store.ceiling_directories
endfunction

" ── Exec paths cache (was s:exec_paths) ─────────────────────────────

function! ghostgit#state#GetExecPaths() abort
  if !has_key(s:store, 'exec_paths')
    let s:store.exec_paths = {}
  endif
  return s:store.exec_paths
endfunction

" ── Path subcommands cache (was s:path_subcommands) ─────────────────

function! ghostgit#state#GetPathSubcommands() abort
  if !has_key(s:store, 'path_subcommands')
    let s:store.path_subcommands = {}
  endif
  return s:store.path_subcommands
endfunction

" ── Status reload times (was s:last_time / s:last_times) ────────────

function! ghostgit#state#GetReloadTimers() abort
  if !has_key(s:store, 'reload_timers')
    let s:store.reload_timers = {}
  endif
  return s:store.reload_timers
endfunction

function! ghostgit#state#ClearReloadTimer(dir) abort
  let timers = ghostgit#state#GetReloadTimers()
  if has_key(timers, a:dir)
    call timer_stop(remove(timers, a:dir))
  endif
endfunction

function! ghostgit#state#GetLastTime() abort
  if !has_key(s:store, 'last_time')
    let s:store.last_time = reltime()
  endif
  return s:store.last_time
endfunction

function! ghostgit#state#SetLastTime() abort
  let s:store.last_time = reltime()
endfunction

function! ghostgit#state#GetLastTimes() abort
  if !has_key(s:store, 'last_times')
    let s:store.last_times = {}
  endif
  return s:store.last_times
endfunction

" ── Trees / indexes cache (was s:trees / s:indexes) ─────────────────

function! ghostgit#state#GetTrees() abort
  if !has_key(s:store, 'trees')
    let s:store.trees = {}
  endif
  return s:store.trees
endfunction

function! ghostgit#state#GetIndexes() abort
  if !has_key(s:store, 'indexes')
    let s:store.indexes = {}
  endif
  return s:store.indexes
endfunction

" ── Edit jobs (was s:edit_jobs) ─────────────────────────────────────

function! ghostgit#state#GetEditJobs() abort
  if !has_key(s:store, 'edit_jobs')
    let s:store.edit_jobs = {}
  endif
  return s:store.edit_jobs
endfunction

" ── Hash colors (was s:hash_colors) ─────────────────────────────────

function! ghostgit#state#GetHashColors() abort
  if !has_key(s:store, 'hash_colors')
    let s:store.hash_colors = {}
  endif
  return s:store.hash_colors
endfunction

" ── Summary format (was g:fugitive_summary_format) ──────────────────

function! ghostgit#state#GetSummaryFormat() abort
  return get(g:, 'ghostgit_summary_format', '%s')
endfunction

function! ghostgit#state#SetSummaryFormat(fmt) abort
  let g:ghostgit_summary_format = a:fmt
endfunction

" ── Origin buffer tracking ──────────────────────────────────────────

function! ghostgit#util#OriginBufnr(...) abort
  let state = ghostgit#state#GetTempState(a:0 ? a:1 : bufnr(''))
  return get(state, 'origin_bufnr', -1)
endfunction
