" autoload/ghostgit/diff.vim — Diffsplit, mergetool, conflict helpers
" Migrated from autoload/fugitive.vim Section: :Gdiff (lines 6534–6752)

" ── Diff header pattern ─────────────────────────────────────────────

let s:diff_header_pattern = '^diff --git \%("\=[abciow12]/.*\|/dev/null\) \%("\=[abciow12]/.*\|/dev/null\)$'

" ── Diff window helpers ─────────────────────────────────────────────

function! s:can_diffoff(buf) abort
  return getwinvar(bufwinnr(a:buf), '&diff') &&
        \ !empty(getwinvar(bufwinnr(a:buf), 'ghostgit_diff_restore'))
endfunction

function! ghostgit#diff#CanDiffoff(buf) abort
  return s:can_diffoff(bufnr(a:buf))
endfunction

function! s:diffthis() abort
  if !&diff
    let w:ghostgit_diff_restore = 1
    diffthis
  endif
endfunction

" ── Diff modifier ───────────────────────────────────────────────────

function! s:diff_modifier(count, directional) abort
  let fdc = matchstr(&diffopt, 'foldcolumn:\zs\d\+')
  if &diffopt =~# 'horizontal' && &diffopt !~# 'vertical'
    return ''
  elseif &diffopt =~# 'vertical'
    return 'vertical '
  elseif !get(g:, 'ghostgit_diffsplit_directional_fit', a:directional)
    return ''
  elseif winwidth(0) <= a:count * ((&tw ? &tw : 80) + (empty(fdc) ? 2 : fdc))
    return ''
  else
    return 'vertical '
  endif
endfunction

" ── Conflict check ──────────────────────────────────────────────────

function! s:is_conflicted() abort
  return len(@%) && !empty(ghostgit#git#ChompDefault('', ['ls-files', '--unmerged', '--', expand('%:p')]))
endfunction

" ── Diffsplit ───────────────────────────────────────────────────────

function! ghostgit#diff#Diffsplit(autodir, keepfocus, mods, arg, ...) abort
  exe ghostgit#core#VersionCheck()
  let args = s:arg_split(a:arg)
  let post = ''
  let autodir = a:autodir
  while get(args, 0, '') =~# '^++'
    if args[0] =~? '^++novertical$'
      let autodir = 0
    else
      return 'echoerr ' . string('ghostgit: unknown option ' . args[0])
    endif
    call remove(args, 0)
  endwhile
  if get(args, 0) =~# '^+'
    let post = remove(args, 0)[1:-1]
  endif
  if exists(':DiffGitCached') && empty(args)
    return s:mods(a:mods) . 'DiffGitCached' . (len(post) ? '|' . post : '')
  endif
  let commit = ghostgit#core#DirCommitFile(@%)[1]
  if a:mods =~# '\<\d*tab\>'
    let mods = substitute(a:mods, '\<\d*tab\>', '', 'g')
    let pre = matchstr(a:mods, '\<\d*tab\>') . ' split'
  else
    let mods = 'keepalt ' . a:mods
    let pre = ''
  endif
  let back = exists('*win_getid') ? 'call win_gotoid(' . win_getid() . ')' : 'wincmd p'
  if (empty(args) || args[0] =~# '^>\=:$') && a:keepfocus
    if commit =~# '^1\=$' && s:is_conflicted()
      let parents = [ghostgit#buffer#Relative(':2:'), ghostgit#buffer#Relative(':3:')]
    elseif empty(commit)
      let parents = [ghostgit#buffer#Relative(':0:')]
    elseif commit =~# '^\d\=$'
      let parents = [ghostgit#buffer#Relative('@:')]
    elseif commit =~# '^\x\x\+$'
      let parents = ghostgit#git#LinesError(['rev-parse', commit . '^@'])[0]
      call map(parents, 'ghostgit#buffer#Relative(v:val . ":")')
    endif
  endif
  exe ghostgit#core#DirCheck()
  try
    if exists('parents') && len(parents) > 1
      exe pre
      let mods = (autodir ? s:diff_modifier(len(parents) + 1, empty(args) || args[0] =~# '^>') : '') . s:mods(mods, 'leftabove')
      let nr = bufnr('')
      if len(parents) > 1 && !&equalalways
        let equalalways = 0
        set equalalways
      endif
      execute mods 'split' ghostgit#util#FnameEscape(ghostgit#buffer#Find(parents[0]))
      call ghostgit#util#Map('n', 'dp', ':diffput '.nr.'<Bar>diffupdate<CR>', '<silent>')
      let nr2 = bufnr('')
      call s:diffthis()
      exe back
      call ghostgit#util#Map('n', 'd2o', ':diffget '.nr2.'<Bar>diffupdate<CR>', '<silent>')
      let mods = substitute(mods, '\Cleftabove\|rightbelow\|aboveleft\|belowright', '\=submatch(0) =~# "f" ? "rightbelow" : "leftabove"', '')
      for i in range(len(parents)-1, 1, -1)
        execute mods 'split' ghostgit#util#FnameEscape(ghostgit#buffer#Find(parents[i]))
        call ghostgit#util#Map('n', 'dp', ':diffput '.nr.'<Bar>diffupdate<CR>', '<silent>')
        let nrx = bufnr('')
        call s:diffthis()
        exe back
        call ghostgit#util#Map('n', 'd' . (i + 2) . 'o', ':diffget '.nrx.'<Bar>diffupdate<CR>', '<silent>')
      endfor
      call s:diffthis()
      return post
    elseif len(args)
      let arg = join(args, ' ')
      if arg ==# ''
        return post
      elseif arg ==# ':/'
        let file = ghostgit#buffer#Relative()
      elseif arg ==# ':'
        let file = len(commit) ? ghostgit#buffer#Relative() : ghostgit#buffer#Relative(s:is_conflicted() ? ':1:' : ':0:')
      elseif arg =~# '^:\d$'
        let file = ghostgit#buffer#Relative(arg . ':')
      elseif arg =~# '^[~^]\d*$'
        return 'echoerr ' . string('ghostgit: change ' . arg . ' to !' . arg . ' to diff against ancestor')
      else
        try
          let file = arg =~# '^:/.' ? ghostgit#git#RevParse(arg) . ghostgit#buffer#Relative(':') : ghostgit#buffer#Expand(arg)
        catch /^ghostgit:/
          return 'echoerr ' . string(v:exception)
        endtry
      endif
      if a:keepfocus || arg =~# '^>'
        let mods = s:mods(a:mods, 'leftabove')
      else
        let mods = s:mods(a:mods)
      endif
    elseif exists('parents')
      let file = get(parents, -1, ghostgit#buffer#Relative(repeat('0', 40). ':'))
      let mods = s:mods(a:mods, 'leftabove')
    elseif len(commit)
      let file = ghostgit#buffer#Relative()
      let mods = s:mods(a:mods, 'rightbelow')
    elseif s:is_conflicted()
      let file = ghostgit#buffer#Relative(':1:')
      let mods = s:mods(a:mods, 'leftabove')
      if get(g:, 'ghostgit_legacy_commands', 1)
        let post = 'echohl WarningMsg|echo "Use :Gdiffsplit! for 3 way diff"|echohl NONE|' . post
      endif
    else
      let file = ghostgit#buffer#Relative(':0:')
      let mods = s:mods(a:mods, 'leftabove')
    endif
    let spec = ghostgit#buffer#Generate(file)
    if spec =~# '^ghostgit:' && empty(ghostgit#core#DirCommitFile(spec)[2])
      let spec = ghostgit#util#VimSlash(spec . ghostgit#buffer#Relative('/'))
    endif
    exe pre
    let w:ghostgit_diff_restore = 1
    let mods = (autodir ? s:diff_modifier(2, empty(args) || args[0] =~# '^>') : '') . mods
    if &diffopt =~# 'vertical'
      let diffopt = &diffopt
      set diffopt-=vertical
    endif
    execute mods 'diffsplit' ghostgit#util#FnameEscape(spec)
    let w:ghostgit_diff_restore = 1
    if getwinvar('#', '&diff')
      call s:diffthis()
    endif
    if !a:keepfocus
      call s:diffthis()
    else
      exe back
    endif
    return post
  finally
    if exists('diffopt')
      let &diffopt = diffopt
    endif
  endtry
endfunction

" ── Diff close ──────────────────────────────────────────────────────

function! ghostgit#diff#DiffClose() abort
  let curwin = winnr()
  for nr in range(1, winnr('$'))
    if getwinvar(nr, '&diff')
      let restore = getwinvar(nr, 'ghostgit_diff_restore')
      if !empty(restore)
        call setwinvar(nr, 'ghostgit_diff_restore', '')
      endif
    endif
  endfor
  for nr in range(1, winnr('$'))
    if getwinvar(nr, '&diff')
      execute nr . 'wincmd w'
      diffoff
    endif
  endfor
  execute curwin . 'wincmd w'
endfunction

" ── Arg split ───────────────────────────────────────────────────────
" NOTE: Does not handle escaped quotes (e.g., \" inside \"...\").
" Low risk for Git argument parsing — keep if it stays internal.

function! s:arg_split(arg) abort
  if empty(a:arg)
    return []
  endif
  let args = []
  let arg = a:arg
  while arg =~# '\S'
    let match = matchstr(arg, '^\s*\%("[^"]*"\|''[^'']*''\|\S\+\)')
    let arg = strpart(arg, len(match))
    call add(args, substitute(match, '^\s*\%("\|''\)\|\%("\|''\)$', '', 'g'))
  endwhile
  return args
endfunction

function! s:mods(mods, ...) abort
  return ghostgit#util#Mods(a:mods, a:0 ? a:1 : '')
endfunction
