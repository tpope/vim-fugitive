if exists('b:did_ftplugin') || &filetype !=# 'fugitive'
  finish
endif
let b:did_ftplugin = 1

setl foldmethod=syntax foldlevel=1
let w:fugitive_status=FugitiveGitDir()
