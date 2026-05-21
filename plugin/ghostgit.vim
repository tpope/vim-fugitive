" ghostgit.vim - A Git wrapper so awesome, it should be illegal
" Maintainer:   GhostGit
" Version:      0.1
" Based on vim-fugitive by Tim Pope

if exists('g:loaded_ghostgit')
  finish
endif
let g:loaded_ghostgit = 1

let s:bad_git_dir = '/$\|^ghostgit:'

" ── Public API (Fugitive-compatible) ────────────────────────────────

function! FugitiveGitDir(...) abort
  return call('ghostgit#core#GitDir', a:000)
endfunction

function! FugitiveReal(...) abort
  return call('ghostgit#core#Real', a:000)
endfunction

function! FugitiveFind(...) abort
  return call('ghostgit#buffer#Find', a:000)
endfunction

function! FugitiveHead(...) abort
  return call('ghostgit#git#Head', a:000)
endfunction

function! FugitiveExecute(args, ...) abort
  return call('ghostgit#git#Execute', [a:args] + a:000)
endfunction

function! FugitiveResult(...) abort
  return call('ghostgit#job#Result', a:000)
endfunction

function! FugitiveDidChange(...) abort
  return call('ghostgit#status#DidChange', a:000)
endfunction

function! FugitiveConfig(...) abort
  return call('ghostgit#config#Config', a:000)
endfunction

function! FugitiveConfigGet(name, ...) abort
  return get(call('FugitiveConfigGetAll', [a:name] + (a:0 ? [a:1] : [])), -1, get(a:, 2, ''))
endfunction

function! FugitiveConfigGetAll(name, ...) abort
  return call('ghostgit#config#GetAll', [a:name] + a:000)
endfunction

function! FugitiveConfigGetRegexp(pattern, ...) abort
  return call('ghostgit#config#GetRegexp', [a:pattern] + a:000)
endfunction

function! FugitiveRemoteUrl(...) abort
  return call('ghostgit#remote#RemoteUrl', a:000)
endfunction

function! FugitiveRemote(...) abort
  return call('ghostgit#remote#Remote', a:000)
endfunction

function! FugitiveShellCommand(...) abort
  return call('ghostgit#git#ShellCommand', a:000)
endfunction

function! FugitiveStatusline(...) abort
  if empty(ghostgit#core#GitDir(bufnr('')))
    return ''
  endif
  return ghostgit#statusline#Statusline()
endfunction

function! FugitivePath(...) abort
  return call('ghostgit#core#Path', a:000)
endfunction

function! FugitiveGitVersion(...) abort
  return call('ghostgit#git#GitVersion', a:000)
endfunction

function! FugitiveParse(...) abort
  return call('ghostgit#core#Parse', a:000)
endfunction

" ── Additional ghostgit API ─────────────────────────────────────────

function! GhostgitGitDir(...) abort
  return call('ghostgit#core#GitDir', a:000)
endfunction

function! GhostgitReal(...) abort
  return call('ghostgit#core#Real', a:000)
endfunction

function! GhostgitFind(...) abort
  return call('ghostgit#buffer#Find', a:000)
endfunction

function! GhostgitHead(...) abort
  return call('ghostgit#git#Head', a:000)
endfunction

function! GhostgitExecute(...) abort
  return call('ghostgit#git#Execute', a:000)
endfunction

function! GhostgitResult(...) abort
  return call('ghostgit#job#Result', a:000)
endfunction

function! GhostgitDidChange(...) abort
  return call('ghostgit#status#DidChange', a:000)
endfunction

function! GhostgitConfig(...) abort
  return call('ghostgit#config#Config', a:000)
endfunction

function! GhostgitConfigGet(name, ...) abort
  return call('ghostgit#config#Get', [a:name] + a:000)
endfunction

function! GhostgitConfigGetAll(name, ...) abort
  return call('ghostgit#config#GetAll', [a:name] + a:000)
endfunction

function! GhostgitConfigGetRegexp(pattern, ...) abort
  return call('ghostgit#config#GetRegexp', [a:pattern] + a:000)
endfunction

function! GhostgitRemoteUrl(...) abort
  return call('ghostgit#remote#RemoteUrl', a:000)
endfunction

function! GhostgitRemote(...) abort
  return call('ghostgit#remote#Remote', a:000)
endfunction

function! GhostgitShellCommand(...) abort
  return call('ghostgit#git#ShellCommand', a:000)
endfunction

function! GhostgitStatusline(...) abort
  return ghostgit#statusline#Statusline()
endfunction

function! GhostgitPath(...) abort
  return call('ghostgit#core#Path', a:000)
endfunction

function! GhostgitGitVersion(...) abort
  return call('ghostgit#git#GitVersion', a:000)
endfunction

function! GhostgitParse(...) abort
  return call('ghostgit#core#Parse', a:000)
endfunction

" ── io_ghostgit (virtual filesystem) ────────────────────────────────

let g:io_ghostgit = {
      \ 'simplify': function('ghostgit#buffer#Simplify'),
      \ 'resolve': function('ghostgit#buffer#Resolve'),
      \ 'getftime': function('ghostgit#buffer#GetFtime'),
      \ 'getfsize': function('ghostgit#buffer#GetFsize'),
      \ 'getftype': function('ghostgit#buffer#GetFtype'),
      \ 'filereadable': function('ghostgit#buffer#FileReadable'),
      \ 'filewritable': function('ghostgit#buffer#FileWritable'),
      \ 'isdirectory': function('ghostgit#buffer#IsDirectory'),
      \ 'getfperm': function('ghostgit#buffer#GetFperm'),
      \ 'setfperm': function('ghostgit#buffer#SetFperm'),
      \ 'readfile': function('ghostgit#buffer#ReadFile'),
      \ 'writefile': function('ghostgit#buffer#WriteFile'),
      \ 'glob': function('ghostgit#buffer#Glob'),
      \ 'delete': function('ghostgit#buffer#Delete'),
      \ 'Real': function('GhostgitReal')}

" ── Commands ────────────────────────────────────────────────────────

let s:addr_other = has('patch-8.1.560') || has('nvim-0.5.0') ? '-addr=other' : ''
let s:addr_tabs  = has('patch-7.4.542') ? '-addr=tabs' : ''
let s:addr_wins  = has('patch-7.4.542') ? '-addr=windows' : ''

if exists(':G') != 2
  command! -bang -nargs=? -range=-1 -complete=customlist,ghostgit#command#Complete G   exe ghostgit#command#Git(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)
endif
command! -bang -nargs=? -range=-1 -complete=customlist,ghostgit#command#Complete Git exe ghostgit#command#Git(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)

command! -bar -bang -nargs=? -complete=customlist,ghostgit#command#CdComplete Gcd  exe ghostgit#command#Cd(<q-args>, 0)
command! -bar -bang -nargs=? -complete=customlist,ghostgit#command#CdComplete Glcd exe ghostgit#command#Cd(<q-args>, 1)

exe 'command! -bang -nargs=? -range=-1' s:addr_wins '-complete=customlist,ghostgit#command#GrepComplete Ggrep  exe ghostgit#command#GrepCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bang -nargs=? -range=-1' s:addr_wins '-complete=customlist,ghostgit#command#GrepComplete Glgrep exe ghostgit#command#GrepCommand(0, <count> > 0 ? <count> : 0, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -nargs=*                          -complete=customlist,ghostgit#command#EditComplete   Ge       exe ghostgit#command#Open("edit<bang>", 0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=*                          -complete=customlist,ghostgit#command#EditComplete   Gedit    exe ghostgit#command#Open("edit<bang>", 0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=*                          -complete=customlist,ghostgit#command#EditComplete   Gpedit   exe ghostgit#command#Open("pedit", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -range=-1' s:addr_other '-complete=customlist,ghostgit#command#EditComplete   Gsplit   exe ghostgit#command#Open((<count> > 0 ? <count> : "").(<count> ? "split" : "edit"), <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -range=-1' s:addr_other '-complete=customlist,ghostgit#command#EditComplete   Gvsplit  exe ghostgit#command#Open((<count> > 0 ? <count> : "").(<count> ? "vsplit" : "edit!"), <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -range=-1' s:addr_tabs  '-complete=customlist,ghostgit#command#EditComplete   Gtabedit exe ghostgit#command#Open((<count> >= 0 ? <count> : "")."tabedit", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=*                          -complete=customlist,ghostgit#command#EditComplete   Gdrop    exe ghostgit#command#DropCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

if exists(':Gr') != 2
  exe 'command! -bar -bang -nargs=* -range=-1                -complete=customlist,ghostgit#command#ReadComplete   Gr     exe ghostgit#command#ReadCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
endif
exe 'command! -bar -bang -nargs=* -range=-1                -complete=customlist,ghostgit#command#ReadComplete   Gread    exe ghostgit#command#ReadCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -nargs=* -complete=customlist,ghostgit#command#EditComplete Gdiffsplit  exe ghostgit#diff#Diffsplit(1, <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,ghostgit#command#EditComplete Ghdiffsplit exe ghostgit#diff#Diffsplit(0, <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,ghostgit#command#EditComplete Gvdiffsplit exe ghostgit#diff#Diffsplit(0, <bang>0, "vertical <mods>", <q-args>)'

exe 'command! -bar -bang -nargs=* -complete=customlist,ghostgit#command#EditComplete Gw     exe ghostgit#command#WriteCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,ghostgit#command#EditComplete Gwrite exe ghostgit#command#WriteCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=* -complete=customlist,ghostgit#command#EditComplete Gwq    exe ghostgit#command#WqCommand(   <line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -nargs=0 GRemove exe ghostgit#command#RemoveCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=0 GUnlink exe ghostgit#command#UnlinkCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=0 GDelete exe ghostgit#command#DeleteCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=1 -complete=customlist,ghostgit#command#CompleteObject GMove   exe ghostgit#command#MoveCommand(  <line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'
exe 'command! -bar -bang -nargs=1 -complete=customlist,ghostgit#command#RenameComplete GRename exe ghostgit#command#RenameCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

exe 'command! -bar -bang -range=-1 -nargs=* -complete=customlist,ghostgit#command#CompleteObject GBrowse exe ghostgit#browse#BrowseCommand(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)'

" ── Autocommands ────────────────────────────────────────────────────

augroup ghostgit
  autocmd!

  autocmd BufNewFile,BufReadPost *
        \ if exists('b:git_dir') && b:git_dir =~# '^$\|' . s:bad_git_dir |
        \   unlet b:git_dir |
        \ endif
  autocmd FileType           netrw
        \ if exists('b:git_dir') && b:git_dir =~# '^$\|' . s:bad_git_dir |
        \   unlet b:git_dir |
        \ endif
  autocmd BufFilePost            *  unlet! b:git_dir

  autocmd FileType git
        \ call ghostgit#util#Map('n', '<cfile>', ':<C-U>exe <SID>cfile()<CR>', '<silent>')
  autocmd FileType ghostgit
        \ call ghostgit#util#Map('n', '<cfile>', ':<C-U>exe <SID>porcelain_cfile()<CR>', '<silent>')

  autocmd BufReadCmd   ghostgit://*          nested exe ghostgit#buffer#BufReadCmd() |
        \ if &path =~# '^\.\%(,\|$\)' |
        \   let &l:path = substitute(&path, '^\.,\=', '', '') |
        \ endif
  autocmd BufWriteCmd  ghostgit://*          nested exe ghostgit#buffer#BufWriteCmd()
  autocmd FileReadCmd  ghostgit://*          nested exe ghostgit#buffer#FileReadCmd()
  autocmd FileWriteCmd ghostgit://*          nested exe ghostgit#buffer#FileWriteCmd()
  if exists('##SourceCmd')
    autocmd SourceCmd     ghostgit://*       nested exe ghostgit#buffer#SourceCmd()
  endif

  autocmd User Flags call Hoist('buffer', function('GhostgitStatusline'))
augroup END

" ── Maps ────────────────────────────────────────────────────────────

nmap <script><silent> <Plug>ghostgit:y<C-G> :<C-U>call setreg(v:register, ghostgit#buffer#Object(@%))<CR>
nmap <script> <Plug>ghostgit: <Nop>

if get(g:, 'ghostgit_no_maps')
  finish
endif

function! s:Map(mode, lhs, rhs, flags) abort
  let flags = a:flags . (a:rhs =~# '<Plug>' ? '' : '<script>') . '<nowait>'
  let head = a:lhs
  let tail = ''
  let keys = get(g:, a:mode.'remap', {})
  if len(keys) && type(keys) == type({})
    while !empty(head)
      if has_key(keys, head)
        let head = keys[head]
        if empty(head)
          return
        endif
        break
      endif
      let tail = matchstr(head, '<[^<>]*>$\|.$') . tail
      let head = substitute(head, '<[^<>]*>$\|.$', '', '')
    endwhile
  endif
  if empty(mapcheck(head.tail, a:mode))
    exe a:mode.'map' flags head.tail a:rhs
  endif
endfunction

call s:Map('c', '<C-R><C-G>', 'fnameescape(ghostgit#buffer#Object(@%))', '<expr>')
call s:Map('n', 'y<C-G>', ':<C-U>call setreg(v:register, ghostgit#buffer#Object(@%))<CR>', '<silent>')
