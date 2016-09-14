" fugitive.vim - A Git wrapper so awesome, it should be illegal
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      2.2
" GetLatestVimScripts: 2975 1 :AutoInstall: fugitive.vim

if exists('g:loaded_fugitive') || &cp
  finish
endif
let g:loaded_fugitive = 1

augroup fugitive
  autocmd!
  autocmd BufNewFile,BufReadPost * call fugitive#detect(expand('%:p'))
  autocmd FileType           netrw call fugitive#detect(expand('%:p'))
  autocmd User NERDTreeInit,NERDTreeNewRoot call fugitive#detect(b:NERDTreeRoot.path.str())
  autocmd VimEnter * if expand('<amatch>')==''|call fugitive#detect(getcwd())|endif
  autocmd CmdWinEnter * call fugitive#detect(expand('#:p'))
  autocmd BufWinLeave * execute getwinvar(+bufwinnr(+expand('<abuf>')), 'fugitive_leave')
augroup END
