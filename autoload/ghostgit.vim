" autoload/ghostgit.vim — Stable public API delegation layer
"
" This file provides the canonical ghostgit#* public API.
" It does NOT contain heavy logic — it only delegates to internal modules.
"
" Benefits:
"   - Lazy loading: Vim only loads this file when ghostgit#* is called
"   - Backward compatibility: Fugitive*/Ghostgit* in plugin/ghostgit.vim delegate here
"   - Modularity: Each ghostgit#module# stays focused; this is purely delegation
"   - Clean API: Third-party plugins call ghostgit#* instead of ghostgit#module#*

" ── Core API ────────────────────────────────────────────────────────

function! ghostgit#GitDir(...) abort
    return call('ghostgit#core#GitDir', a:000)
endfunction

function! ghostgit#Real(url) abort
    return ghostgit#core#Real(a:url)
endfunction

function! ghostgit#Find(spec, ...) abort
    return call('ghostgit#buffer#Find', [a:spec] + a:000)
endfunction

function! ghostgit#Head(...) abort
    return call('ghostgit#git#Head', a:000)
endfunction

function! ghostgit#Execute(args, ...) abort
    return call('ghostgit#git#Execute', [a:args] + a:000)
endfunction

function! ghostgit#Result(...) abort
    return call('ghostgit#job#Result', a:000)
endfunction

function! ghostgit#DidChange(...) abort
    return call('ghostgit#status#DidChange', a:000)
endfunction

function! ghostgit#Config(...) abort
    return call('ghostgit#config#Config', a:000)
endfunction

function! ghostgit#ConfigGet(name, ...) abort
    return call('ghostgit#config#Get', [a:name] + a:000)
endfunction

function! ghostgit#ConfigGetAll(name, ...) abort
    return call('ghostgit#config#GetAll', [a:name] + a:000)
endfunction

function! ghostgit#ConfigGetRegexp(pattern, ...) abort
    return call('ghostgit#config#GetRegexp', [a:pattern] + a:000)
endfunction

function! ghostgit#RemoteUrl(...) abort
    return call('ghostgit#remote#RemoteUrl', a:000)
endfunction

function! ghostgit#Remote(...) abort
    return call('ghostgit#remote#Remote', a:000)
endfunction

function! ghostgit#ShellCommand(...) abort
    return call('ghostgit#git#ShellCommand', a:000)
endfunction

function! ghostgit#Statusline(...) abort
    if empty(ghostgit#core#GitDir(bufnr('')))
        return ''
    endif
    return ghostgit#statusline#Statusline()
endfunction

function! ghostgit#Path(url, ...) abort
    return call('ghostgit#core#Path', [a:url] + a:000)
endfunction

function! ghostgit#GitVersion(...) abort
    return call('ghostgit#git#GitVersion', a:000)
endfunction

function! ghostgit#Parse(url) abort
    return ghostgit#core#Parse(a:url)
endfunction

" ── Feature API ─────────────────────────────────────────────────────

function! ghostgit#Blame(...) abort
    let file = a:0 ? a:1 : expand('%:p')
    let dir = ghostgit#core#GitDir()
    if empty(dir)
        return 'echoerr ' . string('ghostgit: not a git repository')
    endif
    let args = a:0 > 1 ? a:000[1:-1] : []
    let cmd = [dir, 'blame', '--', file] + args
    let result = ghostgit#git#Execute(cmd)
    if result.exit_status
        return 'echoerr ' . string('ghostgit: ' . join(get(result, 'stderr', []), "\n"))
    endif
    call ghostgit#status#DidChange(result)
    return ''
endfunction

function! ghostgit#Browse(...) abort
    let line1 = a:0 > 0 ? a:000[0] : 0
    let count  = a:0 > 1 ? a:000[1] : -1
    let range  = a:0 > 2 ? a:000[2] : 0
    let bang   = a:0 > 3 ? a:000[3] : 0
    let mods   = a:0 > 4 ? a:000[4] : ''
    let arg    = a:0 > 5 ? a:000[5] : ''
    return ghostgit#browse#BrowseCommand(line1, count, range, bang, mods, arg)
endfunction

function! ghostgit#Diffsplit(...) abort
    let autodir    = a:0 > 0 ? a:000[0] : 1
    let keepfocus  = a:0 > 1 ? a:000[1] : 0
    let mods       = a:0 > 2 ? a:000[2] : ''
    let arg        = a:0 > 3 ? a:000[3] : ''
    return ghostgit#diff#Diffsplit(autodir, keepfocus, mods, arg)
endfunction

function! ghostgit#DiffClose() abort
    return ghostgit#diff#DiffClose()
endfunction

function! ghostgit#Reload() abort
    return ghostgit#status#Reload()
endfunction

" ── Command API ─────────────────────────────────────────────────────

function! ghostgit#Command(line1, line2, range, bang, mods, arg, ...) abort
    return call('ghostgit#command#Git', [a:line1, a:line2, a:range, a:bang, a:mods, a:arg] + a:000)
endfunction

function! ghostgit#Cd(path, ...) abort
    return call('ghostgit#command#Cd', [a:path] + a:000)
endfunction
