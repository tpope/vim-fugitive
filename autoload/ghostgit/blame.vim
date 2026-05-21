" autoload/ghostgit/blame.vim — Blame buffer, annotations, commit metadata
" Migrated from autoload/fugitive.vim Section: :Git blame (lines 6862–7420)

" ── Rebase abbrevs ──────────────────────────────────────────────────

let s:rebase_abbrevs = {
      \ 'p': 'pick', 'r': 'reword', 'e': 'edit', 's': 'squash', 'f': 'fixup',
      \ 'd': 'drop', 'x': 'exec', 'b': 'break'}

" ── Blame helpers ───────────────────────────────────────────────────

function! s:linechars(pattern) abort
  let chars = strlen(ghostgit#util#Gsub(matchstr(getline('.'), a:pattern), '.', '.'))
  if &conceallevel > 1
    for col in range(1, chars)
      let chars -= synconcealed(line('.'), col)[0]
    endfor
  endif
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

function! ghostgit#blame#CommitFileLnum(...) abort
  let line = a:0 ? a:1 : getline('.')
  let state = a:0 > 1 ? a:2 : ghostgit#job#TempState()
  if get(state, 'filetype', '') !=# 'ghostgitblame'
    return ['', '', 0]
  endif
  let commit = matchstr(line, '^\^\=[?*]*\zs\x\+')
  if commit =~# '^0\+$'
    let commit = ''
  elseif has_key(state, 'blame_reverse_end')
    let commit = get(ghostgit#git#LinesError([state.git_dir, 'rev-list', '--ancestry-path', '--reverse', commit . '..' . state.blame_reverse_end])[0], 0, '')
  endif
  let lnum = +matchstr(line, ' \zs\d\+\ze \%((\| *\d\+)\)')
  let path = matchstr(line, '^\^\=[?*]*\x* \+\%(\d\+ \+\d\+ \+\)\=\zs.\{-\}\ze\s*\d\+ \%((\| *\d\+)\)')
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
  let cmd = ghostgit#blame#Leave()
  if empty(cmd)
    return 'bdelete'
  elseif len(ghostgit#core#DirCommitFile(@%)[1])
    return cmd . '|Gedit'
  else
    return cmd
  endif
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
  for line in getline(1, '$')
    let hash = matchstr(line, '^\^\=[?*]*\zs\x\{6\}')
    if !empty(hash) && !has_key(hash_colors, hash)
      let hash_colors[hash] = printf('GhostgitHash_%s', hash)
      execute 'syntax match ' . hash_colors[hash] . " '" . hash . "' containedin=ALL"
      execute 'highlight link ' . hash_colors[hash] . ' Label'
    endif
  endfor
endfunction

" ── Blame filetype ──────────────────────────────────────────────────

function! ghostgit#blame#FileType() abort
  setlocal nomodeline
  setlocal nomodifiable
  setlocal foldmethod=manual
  call ghostgit#blame#Syntax()
  call s:blame_maps(0)
  let &l:keywordprg = s:keywordprg()
  let b:undo_ftplugin = 'setl keywordprg= foldmethod<'
  if get(g:, 'ghostgit_blame_conceal', 1)
    setlocal conceallevel=2 concealcursor=n
    let b:undo_ftplugin .= ' concealcursor< conceallevel<'
  endif
endfunction

function! s:blame_maps(has_maps) abort
  call ghostgit#util#Map('n', '<2-LeftMouse>', ':<C-U>exe <SID>BlameOpen("edit")<CR>', '<silent>')
  call ghostgit#util#Map('n', '<CR>', ':<C-U>exe <SID>BlameOpen("edit")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'o', ':<C-U>exe <SID>BlameOpen("split")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'p', ':<C-U>exe <SID>BlameOpen("pedit")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'gO', ':<C-U>exe <SID>BlameOpen("vsplit")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'O', ':<C-U>exe <SID>BlameOpen("tabedit")<CR>', '<silent>')
  call ghostgit#util#Map('n', 'q', ':<C-U>bdelete<CR>', '<silent>')
  call ghostgit#util#Map('n', 'S', ':<C-U>echoerr "Use gO"<CR>', '<silent>')
endfunction

" ── Blame complete ──────────────────────────────────────────────────

function! ghostgit#blame#Complete(A, L, P) abort
  return s:complete_sub('blame', a:A, a:L, a:P)
endfunction

function! s:complete_sub(subcommand, A, L, P) abort
  let args = split(a:L[0 : a:P-1], '\s\+')
  let base = a:A
  if base =~# '^-'
    return filter(['--root', '--show-email', '--show-number', '--show-stats', '--porcelain', '--line-porcelain', '--incremental', '--abbrev=', '--contents=', '--reverse', '--progress', '--date=', '-L'], 'stridx(v:val, base) == 0')
  endif
  return ghostgit#command#CompletePath(base)
endfunction
