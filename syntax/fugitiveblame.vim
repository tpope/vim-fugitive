if exists("b:current_syntax")
  finish
endif

call fugitive#AnnotateSyntax()

let b:current_syntax = "fugitiveannotate"
