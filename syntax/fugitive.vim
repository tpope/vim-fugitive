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

hi def link fugitiveModifier Type
hi def link fugitiveHeader Label
hi def link fugitiveHeading PreProc
hi def link fugitiveHash Identifier
hi def link fugitiveSymbolicRef Function
hi def link fugitiveCount Number

let b:current_syntax = "fugitive"
