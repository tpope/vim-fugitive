" autoload/ghostgit/blame.vim — Blame buffer, annotations, commit metadata
" Migrated from autoload/fugitive.vim Section: :Git blame (lines 6862–7420)

" ── Blame helpers ───────────────────────────────────────────────────

let s:linechars_cache = {}

function! s:linechars(pattern) abort
  let lnum = line('.')
  let bnr = bufnr('')
  let key = bnr . ':' . lnum
  if &conceallevel < 2
    let chars = strlen(ghostgit#util#Gsub(matchstr(getline('.'), a:pattern), '.', '.'))
    let s:linechars_cache[key] = chars
    return chars
  endif
  if has_key(s:linechars_cache, key)
    return s:linechars_cache[key]
  endif
  let chars = strlen(ghostgit#util#Gsub(matchstr(getline('.'), a:pattern), '.', '.'))
  let concealed = 0
  for col in range(1, chars)
    let concealed += synconcealed(lnum, col)[0]
  endfor
  let chars -= concealed
  let s:linechars_cache[key] = chars
  return chars
endfunction

function! ghostgit#blame#Bufnr(...) abort
  let state = ghostgit#job#TempState(a:0 ? a:1 : bufnr(''))
  if get(state, 'filetype', '') ==# 'ghostgitblame'
    return get(state, 'origin_bufnr', -1)
  else
    return -1
  endif
endfunction

function! s:ParseBlameLine(line) abort
  let commit = matchstr(a:line, '^\^\=[?*]*\zs\x\+')
  let lnum = +matchstr(a:line, ' \zs\d\+\ze \%((\| *\d\+)\)')
  let path = matchstr(a:line, '^\^\=[?*]*\x* \+\%(\d\+ \+\d\+ \+\)\=\zs.\{-\}\ze\s*\d\+ \%((\| *\d\+)\)')
  return [commit, lnum, path]
endfunction

function! s:ResolveCommit(commit, state) abort
  if a:commit =~# '^0\+$'
    return ''
  endif
  if has_key(a:state, 'blame_reverse_end')
    return get(ghostgit#git#LinesError([a:state.git_dir, 'rev-list', '--ancestry-path', '--reverse', a:commit . '..' . a:state.blame_reverse_end])[0], 0, '')
  endif
  return a:commit
endfunction

function! ghostgit#blame#CommitFileLnum(...) abort
  let line = a:0 ? a:1 : getline('.')
  let state = a:0 > 1 ? a:2 : ghostgit#job#TempState()
  if get(state, 'filetype', '') !=# 'ghostgitblame'
    return ['', '', 0]
  endif
  let [commit, lnum, path] = s:ParseBlameLine(line)
  let commit = s:ResolveCommit(commit, state)
  if empty(path) && lnum
    let path = get(state, 'blame_file', '')
  endif
  return [commit, path, lnum]
endfunction

function! ghostgit#blame#Leave() abort
  let state = ghostgit#job#TempState()
  let bufwinnr = exists('*win_id2win') ? win_id2win(get(state, 'origin_winid')) : 0
  if bufwinnr == 0
    let bufwinnr = bufwinnr(get(state, 'origin_bufnr', -1))
  endif
  if get(state, 'filetype', '') ==# 'ghostgitblame' && bufwinnr > 0
    let bufnr = bufnr('')
    exe bufwinnr . 'wincmd w'
    return bufnr . 'bdelete'
  endif
  return ''
endfunction

function! ghostgit#blame#Quit() abort
  try
    let cmd = ghostgit#blame#Leave()
    if empty(cmd)
      execute 'bdelete'
    else
      execute cmd
      if len(ghostgit#core#DirCommitFile(@%)[1])
        execute 'Gedit'
      endif
    endif
  catch
    call ghostgit#util#Warn('Failed to quit blame buffer: ' . v:exception)
  endtry
endfunction

" ── Keywordprg ──────────────────────────────────────────────────────

function! s:keywordprg() abort
  let args = ' --git-dir=' . escape(ghostgit#core#GitPath(ghostgit#core#GitDir()), "\\\"' ")
  if has('gui_running') && !has('win32')
    return ghostgit#git#GitShellCmd() . ' --no-pager' . args . ' log -1'
  else
    return ghostgit#git#GitShellCmd() . args . ' show'
  endif
endfunction

" ── Blame syntax ────────────────────────────────────────────────────

function! ghostgit#blame#Syntax() abort
  let hash_colors = ghostgit#state#GetHashColors()
  let lines = getline(1, '$')
  let hashes = filter(map(lines, {_, l -> matchstr(l, '^\^\=[?*]*\zs\x\{6\}')}), {_, h -> !empty(h) && !has_key(hash_colors, h)})
  for hash in hashes
    let hash_colors[hash] = printf('GhostgitHash_%s', hash)
    execute 'syntax match ' . hash_colors[hash] . " '" . hash . "' containedin=ALL"
    execute 'highlight link ' . hash_colors[hash] . ' Label'
  endfor
endfunction

" ── Blame filetype ──────────────────────────────────────────────────

function! ghostgit#blame#FileType() abort
  setlocal nomodeline
  setlocal nomodifiable
  setlocal foldmethod=manual
  let s:linechars_cache = {}
  call ghostgit#blame#Syntax()
  call s:blame_maps()
  let &l:keywordprg = s:keywordprg()
  let b:undo_ftplugin = 'setl keywordprg= foldmethod<'
  if get(g:, 'ghostgit_blame_conceal', 1)
    setlocal conceallevel=2 concealcursor=n
    let b:undo_ftplugin .= ' concealcursor< conceallevel<'
  endif
endfunction

function! s:blame_maps() abort
  for key in ['<2-LeftMouse>', '<CR>']
    call ghostgit#util#Map('n', key, ':<C-U>exe <SID>BlameOpen("edit")<CR>', '<silent>')
  endfor
  call ghostgit#util#Map('n', 'o', ':<C-U>exe <SID>BlameOpen("split")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'p', ':<C-U>exe <SID>BlameOpen("pedit")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'gO', ':<C-U>exe <SID>BlameOpen("vsplit")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'O', ':<C-U>exe <SID>BlameOpen("tabedit")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'q', ':<C-U>bdelete<CR>', '<silent>')
  call ghostgit#util#Map('n', 'S', ':<C-U>echoerr "Use gO"<CR>', '<silent>')
endfunction

" ── Blame complete ──────────────────────────────────────────────────

let s:blame_flags = ['--root', '--show-email', '--show-number', '--show-stats', '--porcelain', '--line-porcelain', '--incremental', '--abbrev=', '--contents=', '--reverse', '--progress', '--date=', '-L']

function! ghostgit#blame#Complete(A, L, P) abort
  let args = split(a:L[0 : a:P-1], '\s\+')
  let base = a:A
  if base =~# '^-'
    return filter(copy(s:blame_flags), 'stridx(v:val, base) == 0')
  endif
  return ghostgit#command#CompletePath(base)
endfunction
