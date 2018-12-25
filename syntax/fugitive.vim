if exists("b:current_syntax")
  finish
endif

syn sync fromstart
syn spell notoplevel

syn include @fugitiveDiff syntax/diff.vim

syn match fugitiveHeader /^[A-Z][a-z][^:]*:/ nextgroup=fugitiveHash,fugitiveSymbolicRef skipwhite

syn region fugitiveSection start=/^\%(.*(\d\+)$\)\@=/ contains=fugitiveHeading end=/^$\@=/
syn match fugitiveHeading /^[A-Z][a-z][^:]*\ze (\d\+)$/ contains=fugitivePreposition contained nextgroup=fugitiveCount skipwhite
syn match fugitiveCount /(\d\+)/hs=s+1,he=e-1 contained
syn match fugitivePreposition /\<\%([io]nto\|from\|to\)\>/ transparent contained nextgroup=fugitiveHash,fugitiveSymbolicRef skipwhite

syn match fugitiveModifier /^[MADRCU?]\{1,2} / contained containedin=fugitiveSection
syn match FugitiveSymbolicRef /\.\@!\%(\.\.\@!\|[^[:space:][:cntrl:]\:.]\)\+\.\@<!/ contained
syn match fugitiveHash /^\x\{4,\}\>/ contained containedin=fugitiveSection

syn region fugitiveHunk start=/^\%(@@ -\)\@=/ end=/^\%(diff --\%(git\|cc\|combined\) \|@@\|$\)\@=/ contains=@fugitiveDiff containedin=fugitiveSection fold

hi link fugitiveModifier Type
hi link fugitiveHeader Label
hi link fugitiveHeading PreProc
hi link fugitiveHash Identifier
hi link fugitiveSymbolicRef Function
hi link fugitiveCount Number

let b:current_syntax = "fugitive"
