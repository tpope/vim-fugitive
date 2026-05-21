# Fugitive Architecture — Auditoría Completa

## Resumen

| Métrica | Valor |
|---|---|
| Archivo principal | `autoload/fugitive.vim` |
| Líneas totales | ~8,435 |
| Entry point | `plugin/fugitive.vim` (754 líneas) |
| Funciones públicas (`fugitive#`) | 106 |
| Funciones privadas (`s:`) | ~271 |
| Variables globales `s:` (script-local) | 38 |
| Secciones funcionales | 28 |
| Autocommand groups | 6 (+ 1 en plugin) |
| Comandos `:G*` | ~40 |

---

## 1. Estructura de Archivos

```
plugin/fugitive.vim          → Entry point, API pública, commands, autocommands, maps
autoload/fugitive.vim        → Implementación completa (~8400 líneas)
doc/fugitive.txt             → Documentación (:help fugitive)
ftdetect/fugitive.vim        → Filetype detection
ftplugin/{git,gitcommit}.vim → Filetype plugins
syntax/{git,gitcommit}.vim   → Syntax highlighting
```

---

## 2. Secciones Funcionales (autoload/fugitive.vim)

Las secciones están marcadas con comentarios `" Section: ...`:

| # | Sección | Líneas | Descripción |
|---|---|---|---|
| 1 | **Utility** | 9–184 | Helpers: `s:sub`, `s:gsub`, `s:Slash`, `s:shellesc`, `s:Mods`, `s:fnameescape`, URL encode/decode |
| 2 | **Git** | 458–539 | `s:GitCmd()`, `s:UserCommandList()`, `fugitive#GitVersion()`, detección de binario git |
| 3 | **Git config** | 1050–1209 | `fugitive#Config()`, `ConfigGetAll()`, `ConfigGetRegexp()`, caché de configuración |
| 4 | **Quickfix** | 1507–1593 | `s:QuickfixCreate()`, `s:QuickfixOpen()`, `s:QuickfixStream()`, `fugitive#Cwindow()` |
| 5 | **Repository Object** | 1593–1664 | `fugitive#repo()`, `s:repo_prototype`, objeto repo con métodos `.dir()`, `.tree()` |
| 6 | **File API** | 1664–2394 | `fugitive#Parse()`, `fugitive#Real()`, `fugitive#Path()`, `fugitive#Find()`, `fugitive#Object()`, `fugitive#Expand()`, I/O virtual: `readfile`, `writefile`, `glob`, `delete`, `filereadable`, `isdirectory`, `getftype`, `getfperm`, `setfperm` |
| 7 | **Completion** | 2394–2552 | `fugitive#CompletePath()`, `fugitive#CompleteObject()`, `fugitive#Complete()`, `fugitive#CdComplete()` |
| 8 | **Buffer auto-commands** | 2552–3303 | `fugitive#BufReadStatus()`, `fugitive#BufReadCmd()`, `fugitive#BufWriteCmd()`, `fugitive#FileReadCmd()`, `fugitive#SourceCmd()` |
| 9 | **Temp files** | 3303–3418 | `fugitive#Result()`, `s:TempState()`, `s:TempReadPre()`, `s:TempReadPost()`, gestión de archivos temporales de jobs |
| 10 | **:Git** | 3418–4178 | Comando principal `:Git`, ejecución async, `s:RunEdit()`, `s:RunReceive()`, `s:RunExit()`, `s:RunClose()`, pager integration, `fugitive#Command()` |
| 11 | **:Gcd, :Glcd** | 4178–4195 | Cambio de directorio al root del repo |
| 12 | **:Gstatus** | 4195–5383 | Status buffer, stage/unstage, `s:StageInfo()`, `s:StageSeek()`, `s:ReloadStatus()`, `fugitive#DidChange()` |
| 13 | **:Git commit, :Git revert** | 5383–5441 | Commit workflow, message editing, `fugitive#CommitComplete()` |
| 14 | **:Git merge, :Git rebase, :Git pull** | 5441–5473 | Merge/rebase/pull con completers |
| 15 | **:Git bisect** | 5473–5489 | Bisect subcommand, `fugitive#BisectComplete()` |
| 16 | **:Git difftool, :Git mergetool** | 5489–5733 | Difftool/mergetool wrappers |
| 17 | **:Ggrep, :Glog** | 5733–6122 | `fugitive#GrepCommand()`, `fugitive#LogCommand()`, streaming de resultados |
| 18 | **:Gedit, :Gsplit, etc.** | 6122–6351 | `fugitive#Open()`, `fugitive#DropCommand()`, `fugitive#ReadCommand()`, apertura de buffers fugitive:// |
| 19 | **:Gwrite, :Gwq** | 6351–6497 | `fugitive#WriteCommand()`, `fugitive#WqCommand()`, escritura al index |
| 20 | **:Git push, :Git fetch** | 6497–6534 | Push/fetch con completers |
| 21 | **:Gdiff** | 6534–6752 | `fugitive#Diffsplit()`, `fugitive#DiffClose()`, `fugitive#CanDiffoff()`, diff windows |
| 22 | **:GMove, :GRemove** | 6752–6862 | `fugitive#MoveCommand()`, `fugitive#RenameCommand()`, `fugitive#RemoveCommand()`, `fugitive#DeleteCommand()`, `fugitive#UnlinkCommand()` |
| 23 | **:Git blame** | 6862–7420 | `s:BlameSubcommand()`, `fugitive#BlameSyntax()`, `fugitive#BlameFileType()`, blame buffer |
| 24 | **:GBrowse** | 7420–7818 | `fugitive#BrowseCommand()`, `fugitive#ResolveUrl()`, integración con hosting (GitHub, GitLab, etc.) |
| 25 | **Maps** | 7818–8361 | `fugitive#MapCfile()`, `fugitive#MapJumps()`, `fugitive#GX()`, `fugitive#PorcelainCfile()`, keybindings |
| 26 | **Statusline** | 8361–8381 | `fugitive#Statusline()`, indicador `[Git(branch)]` |
| 27 | **Folding** | 8381–8435 | `fugitive#Foldtext()`, foldtext custom para diffs y status |
| 28 | **End** | 8435 | Fin del archivo |

---

## 3. Funciones Públicas (API)

### 3.1 API Documentada (plugin/fugitive.vim)

| Función | Línea | Descripción |
|---|---|---|
| `FugitiveGitDir([bufnr])` | plugin:18 | Retorna el Git dir para un buffer |
| `FugitiveReal(url)` | plugin:56 | Convierte URL `fugitive://` a path real |
| `FugitiveFind(spec)` | plugin:78 | Resuelve un objeto Fugitive a buffer name |
| `FugitiveHead([truncate], [git_dir])` | plugin:236 | Nombre del branch actual |
| `FugitiveExecute(args, [git_dir], [callback])` | plugin:139 | Ejecuta Git async |
| `FugitiveResult()` | plugin:123 | Resultado del último `:Git` |
| `FugitiveDidChange([bufnr])` | plugin:225 | Dispara evento `FugitiveChanged` |
| `FugitiveConfig()` | plugin:163 | Objeto de configuración |
| `FugitiveConfigGet(name, ...)` | plugin:170 | Valor de config |
| `FugitiveConfigGetAll(name, ...)` | plugin:176 | Todos los valores de config |
| `FugitiveConfigGetRegexp(pattern, ...)` | plugin:184 | Config por regexp |
| `FugitiveRemoteUrl(...)` | plugin:195 | URL del remote |
| `FugitiveRemote(...)` | plugin:213 | Remote parseado |
| `FugitiveShellCommand(...)` | plugin:150 | String de comando Git |
| `FugitiveStatusline()` | plugin:265 | Indicador statusline |
| `FugitivePath(...)` | plugin:253 | Path resolution |
| `FugitiveGitVersion(...)` | plugin:105 | Versión de Git |
| `FugitiveParse(...)` | plugin:89 | Parsea URL fugitive:// |

### 3.2 Funciones Públicas Internas (autoload/fugitive.vim)

| Función | Línea | Descripción |
|---|---|---|
| `fugitive#UrlDecode(str)` | 78 | Decode URL |
| `fugitive#Unquote(string)` | 241 | Unquote Git strings |
| `fugitive#Autowrite()` | 319 | Autowrite trigger |
| `fugitive#Wait(job_or_jobs, ...)` | 336 | Espera jobs async |
| `fugitive#GitVersion(...)` | 540 | Git version check |
| `fugitive#PrepareDirEnvGitFlagsArgs(...)` | 667 | Parse args para :Git |
| `fugitive#PrepareJob(...)` | 798 | Prepara job options |
| `fugitive#Execute(...)` | 824 | Ejecución core de Git |
| `fugitive#ShellCommand(...)` | 903 | Construye comando shell |
| `fugitive#Head(...)` | 1015 | HEAD/branch name |
| `fugitive#RevParse(rev, ...)` | 1042 | Parse revision |
| `fugitive#ExpireConfig(...)` | 1090 | Expira config cache |
| `fugitive#Config(...)` | 1101 | Config object |
| `fugitive#ConfigGetAll(name, ...)` | 1159 | Config values |
| `fugitive#ConfigGetRegexp(pattern, ...)` | 1172 | Config por pattern |
| `fugitive#SshConfig(host, ...)` | 1273 | SSH config parsing |
| `fugitive#SshHostAlias(authority)` | 1292 | SSH host alias |
| `fugitive#RemoteHttpHeaders(remote)` | 1323 | HTTP headers del remote |
| `fugitive#Remote(...)` | 1489 | Remote object |
| `fugitive#RemoteUrl(...)` | 1498 | Remote URL |
| `fugitive#Cwindow()` | 1582 | Quickfix window |
| `fugitive#repo(...)` | 1597 | Repo object (legacy) |
| `fugitive#Parse(url)` | 1679 | Parse fugitive:// URL |
| `fugitive#Real(url)` | 1730 | Real filesystem path |
| `fugitive#Path(url, ...)` | 1748 | Path relative |
| `fugitive#Find(object, ...)` | 1802 | Resolve object |
| `fugitive#Object(...)` | 1939 | Object name |
| `fugitive#Expand(object)` | 2079 | Expand <cword> vars |
| `fugitive#simplify(url)` | 2177 | Simplify URL |
| `fugitive#resolve(url)` | 2196 | Resolve symlink |
| `fugitive#getftime(url)` | 2205 | File mtime |
| `fugitive#getfsize(url)` | 2209 | File size |
| `fugitive#getftype(url)` | 2218 | File type |
| `fugitive#filereadable(url)` | 2222 | File readable check |
| `fugitive#filewritable(url)` | 2226 | File writable check |
| `fugitive#isdirectory(url)` | 2234 | Directory check |
| `fugitive#getfperm(url)` | 2238 | File permissions |
| `fugitive#setfperm(url, perm)` | 2263 | Set permissions |
| `fugitive#readfile(url, ...)` | 2310 | Read file (virtual) |
| `fugitive#writefile(lines, url, ...)` | 2322 | Write file (virtual) |
| `fugitive#glob(url, ...)` | 2352 | Glob (virtual) |
| `fugitive#delete(url, ...)` | 2381 | Delete (virtual) |
| `fugitive#CompletePath(base, ...)` | 2419 | Path completion |
| `fugitive#PathComplete(...)` | 2458 | Path completion wrapper |
| `fugitive#CompleteObject(base, ...)` | 2471 | Object completion |
| `fugitive#BufReadStatus(cmdbang)` | 3063 | Status buffer read |
| `fugitive#FileReadCmd(...)` | 3094 | File read handler |
| `fugitive#FileWriteCmd(...)` | 3118 | File write handler |
| `fugitive#BufReadCmd(...)` | 3154 | Buffer read handler |
| `fugitive#BufWriteCmd(...)` | 3286 | Buffer write handler |
| `fugitive#SourceCmd(...)` | 3290 | Source handler |
| `fugitive#Result(...)` | 3313 | Get result object |
| `fugitive#Resume()` | 3714 | Resume after job |
| `fugitive#CanPty()` | 3755 | PTY capability check |
| `fugitive#PagerFor(argv, ...)` | 3760 | Pager detection |
| `fugitive#Command(line1, line2, ...)` | 3798 | :Git command handler |
| `fugitive#Complete(lead, ...)` | 4148 | Command completion |
| `fugitive#CompleteForWorkingDir(A, L, P, ...)` | 4173 | Completion wrapper |
| `fugitive#CdComplete(A, L, P)` | 4180 | Cd completion |
| `fugitive#Cd(path, ...)` | 4184 | :Gcd/:Glcd handler |
| `fugitive#DidChange(...)` | 4425 | Trigger change event |
| `fugitive#ReloadStatus(...)` | 4438 | Reload status buffer |
| `fugitive#EfmDir(...)` | 4442 | Extract dir from errorformat |
| `fugitive#CommitComplete(A, L, P, ...)` | 5419 | Commit completion |
| `fugitive#RevertComplete(A, L, P, ...)` | 5437 | Revert completion |
| `fugitive#MergeComplete(A, L, P, ...)` | 5443 | Merge completion |
| `fugitive#RebaseComplete(A, L, P, ...)` | 5447 | Rebase completion |
| `fugitive#PullComplete(A, L, P, ...)` | 5451 | Pull completion |
| `fugitive#BisectComplete(A, L, P, ...)` | 5485 | Bisect completion |
| `fugitive#GrepComplete(A, L, P)` | 5739 | Grep completion |
| `fugitive#LogComplete(A, L, P)` | 5743 | Log completion |
| `fugitive#GrepCommand(...)` | 5943 | :Ggrep handler |
| `fugitive#LogCommand(...)` | 6045 | :Glog/:Gllog handler |
| `fugitive#DiffClose()` | 6243 | Close diff windows |
| `fugitive#Open(cmd, bang, mods, arg, ...)` | 6272 | Open buffer |
| `fugitive#DropCommand(...)` | 6290 | :Gdrop handler |
| `fugitive#ReadCommand(...)` | 6325 | :Gread handler |
| `fugitive#EditComplete(A, L, P)` | 6339 | Edit completion |
| `fugitive#ReadComplete(A, L, P)` | 6347 | Read completion |
| `fugitive#WriteCommand(...)` | 6353 | :Gwrite handler |
| `fugitive#WqCommand(...)` | 6484 | :Gwq handler |
| `fugitive#PushComplete(A, L, P, ...)` | 6518 | Push completion |
| `fugitive#FetchComplete(A, L, P, ...)` | 6522 | Fetch completion |
| `fugitive#CanDiffoff(buf)` | 6553 | Diff close check |
| `fugitive#Diffsplit(autodir, ...)` | 6609 | :Gdiffsplit handler |
| `fugitive#RenameComplete(A,L,P)` | 6810 | Rename completion |
| `fugitive#MoveCommand(...)` | 6819 | :GMove handler |
| `fugitive#RenameCommand(...)` | 6823 | :GRename handler |
| `fugitive#RemoveCommand(...)` | 6850 | :GRemove handler |
| `fugitive#UnlinkCommand(...)` | 6854 | :GUnlink handler |
| `fugitive#DeleteCommand(...)` | 6858 | :GDelete handler |
| `fugitive#BlameComplete(A, L, P)` | 6937 | Blame completion |
| `fugitive#BlameSyntax()` | 7278 | Blame syntax setup |
| `fugitive#BlameFileType()` | 7380 | Blame filetype setup |
| `fugitive#BrowseCommand(...)` | 7457 | :GBrowse handler |
| `fugitive#ResolveUrl(target, ...)` | 7743 | URL resolution |
| `fugitive#MapCfile(...)` | 7823 | Map <cfile> |
| `fugitive#MapJumps(...)` | 7988 | Map navigation keys |
| `fugitive#GX()` | 8067 | gx handler |
| `fugitive#PorcelainCfile()` | 8105 | Porcelain cfile |
| `fugitive#Statusline()` | 8363 | Statusline text |
| `fugitive#statusline(...)` | 8377 | Statusline alias |
| `fugitive#Foldtext()` | 8383 | Fold text |
| `fugitive#foldtext()` | 8431 | Foldtext alias |

---

## 4. Mapa de Dependencias

### 4.1 Variables Globales Script-Local (`s:`)

| Variable | Línea | Tipo | Uso |
|---|---|---|---|
| `s:worktree_error` | 121 | string | Mensaje de error |
| `s:quote_chars` | 224 | dict | Quote chars map |
| `s:unquote_chars` | 228 | dict | Unquote chars map |
| `s:executables` | 250 | dict | Cache de executables |
| `s:run_jobs` | 460 | bool | Flag de soporte jobs |
| `s:git_versions` | 539 | dict | Cache de versiones git |
| `s:git_index_file_env` | 641 | dict | Cache de GIT_INDEX_FILE |
| `s:prepare_env` | 662 | dict | Env vars para git |
| `s:head_cache` | 1013 | dict | Cache de HEAD |
| `s:config_prototype` | 1087 | dict | Prototype para config |
| `s:config` | 1089 | dict | Cache de config |
| `s:remote_headers` | 1321 | dict | Cache de headers HTTP |
| `s:repo_prototype` | 1595 | dict | Prototype para repo |
| `s:merge_heads` | 1683 | list | HEADs de merge |
| `s:var` | 1963 | string | Pattern para expand |
| `s:flag` | 1964 | string | Pattern para flags |
| `s:expand` | 1965 | string | Pattern para expansion |
| `s:commit_expand` | 1966 | string | Pattern para commit |
| `s:trees` | 2112 | dict | Cache de trees |
| `s:indexes` | 2113 | dict | Cache de indexes |
| `s:globsubs` | 2344 | dict | Glob substitutions |
| `s:rebase_abbrevs` | 2667 | dict | Rebase abbreviations |
| `s:disable_colors` | 3793 | list | Color disable list |
| `s:exec_paths` | 4080 | dict | Cache de exec paths |
| `s:subcommands_before_2_5` | 4094 | list | Subcommands legacy |
| `s:path_subcommands` | 4104 | dict | Path subcommands cache |
| `s:last_time` | 4359 | time | Last status reload |
| `s:file_pattern` | 4710 | string | File detection pattern |
| `s:file_commit_pattern` | 4711 | string | File+commit pattern |
| `s:item_pattern` | 4712 | string | Item detection pattern |
| `s:section_pattern` | 4797 | string | Section pattern |
| `s:section_commit_pattern` | 4798 | string | Section+commit pattern |
| `s:grep_combine_flags` | 5793 | string | Grep flags pattern |
| `s:log_diff_context` | 5948 | string | Log diff context template |
| `s:bang_edits` | 6271 | dict | Bang edit mappings |
| `s:hash_colors` | 7276 | dict | Hash color cache |
| `s:ref_header` | 7820 | string | Ref header pattern |
| `s:diff_header_pattern` | 8144 | string | Diff header pattern |

### 4.2 Variables Globales (`g:`)

| Variable | Línea | Tipo | Mutación |
|---|---|---|---|
| `g:loaded_fugitive` | plugin:9 | bool | Set una vez al cargar |
| `g:fugitive_event` | plugin:22 / autoload:3477,4326 | string | Set durante eventos `FugitiveChanged` |
| `g:fugitive_result` | autoload:3478,4328 | dict | Set durante eventos `FugitiveChanged` |
| `g:fugitive_did_change_at` | autoload:4428 | time | Timestamp del último cambio |
| `g:fugitive_summary_format` | autoload:5736 | string | Formato de summary |
| `g:_fugitive_last_job` | autoload:3440 | dict | Último job ejecutado |

### 4.3 Variables de Buffer (`b:`)

| Variable | Línea | Uso |
|---|---|---|
| `b:git_dir` | plugin:25 | Git dir del buffer |
| `b:fugitive_type` | autoload:3029,3068 | Tipo de buffer fugitive |
| `b:fugitive_loading` | autoload:3071 | Estado de carga |
| `b:fugitive_display_format` | autoload:3193 | Formato de display |
| `b:fugitive_expanded` | autoload:4954 | Archivos expandidos en status |
| `b:dispatch` | autoload:3084 | Dispatch command |
| `b:man_sect` | autoload:3381 | Man page section |
| `b:undo_ftplugin` | autoload:7386 | Undo para ftplugin |

### 4.4 Variables de Window (`w:`)

| Variable | Línea | Uso |
|---|---|---|
| `w:fugitive_status` | autoload:4216 | Git dir del status window |
| `w:fugitive_diff_restore` | autoload:6582,6725,6732 | Flag para restaurar diff |
| `w:fugitive_leave` | autoload:7146 | Comandos al salir del blame |

### 4.5 Estado Global Compartido (Coupling Crítico)

| Estado | Variables | Secciones que lo mutan |
|---|---|---|
| **Temp files registry** | `s:temp_files` | :Git (s:RunSave), Temp files (s:TempState, s:TempDelete) |
| **HEAD cache** | `s:head_cache` | Git config (fugitive#ExpireConfig), Status (s:ExpireStatus) |
| **Config cache** | `s:config`, `s:config_prototype` | Git config (fugitive#Config, fugitive#ExpireConfig) |
| **Worktree cache** | `s:worktree_for_dir`, `s:dir_for_worktree` | plugin (s:Tree), FugitiveExtractGitDir |
| **Common dirs** | `s:commondirs` | plugin (FugitiveCommonDir) |
| **Resolved git dirs** | `s:resolved_git_dirs` | plugin (FugitiveActualDir, FugitiveExtractGitDir) |
| **Git versions** | `s:git_versions` | Git (fugitive#GitVersion) |
| **Last job** | `g:_fugitive_last_job` | :Git (s:RunFinished), fugitive#Result |
| **Event state** | `g:fugitive_event`, `g:fugitive_result` | Status (s:DoAutocmdChanged), :Git (s:RunEdit) |
| **Last reload time** | `s:last_time`, `s:last_times` | Status (s:ExpireStatus, s:ReloadWinStatus) |
| **Edit jobs** | `s:edit_jobs` | :Git (s:RunEdit) |
| **Trees/indexes cache** | `s:trees`, `s:indexes` | File API (fugitive#readfile, fugitive#writefile) |

---

## 5. Autocommand Groups

| Group | Archivo | Autocommands | Propósito |
|---|---|---|---|
| `fugitive` | plugin:660-721 | BufNewFile, BufReadPost, FileType, BufFilePost, BufReadCmd, BufWriteCmd, FileReadCmd, FileWriteCmd, SourceCmd, User | Core lifecycle, filetype detection, buffer commands |
| `fugitive_dummy_events` | autoload:2554 | User FugitiveIndex | Dummy event para compatibilidad |
| `fugitive_temp` | autoload:3411 | BufReadPre, BufReadPost, BufWipeout | Temp file lifecycle |
| `fugitive_job` | autoload:3744 | VimLeavePre, ExitPre | Job cleanup on exit |
| `fugitive_status` | autoload:4449 | BufWritePost, ShellCmdPost, BufDelete, QuickFixCmdPost, FocusGained, BufEnter, TabEnter, User | Auto-reload del status buffer |
| `fugitive_diff` | autoload:6536 | BufWinLeave, BufWinEnter | Diff window cleanup |
| `fugitive_blame` | autoload:7412 | BufEnter | Blame buffer setup |

---

## 6. Comandos Definidos

### 6.1 Comandos Principales (plugin/fugitive.vim)

| Comando | Línea | Handler |
|---|---|---|
| `:G` | plugin:548 | `fugitive#Command()` |
| `:Git` | plugin:550 | `fugitive#Command()` |
| `:Gstatus` | plugin:552 | `fugitive#Command()` (deprecated) |
| `:Gcommit` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Grevert` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Gmerge` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Grebase` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Gpull` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Gpush` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Gfetch` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Gblame` | plugin:557 | `fugitive#Command()` (deprecated) |
| `:Gcd` | plugin:566 | `fugitive#Cd()` |
| `:Glcd` | plugin:567 | `fugitive#Cd()` |
| `:Ggrep` | plugin:569 | `fugitive#GrepCommand()` |
| `:Glgrep` | plugin:570 | `fugitive#GrepCommand()` |
| `:Gclog` / `:GcLog` | plugin:572 | `fugitive#LogCommand()` |
| `:Gllog` / `:GlLog` | plugin:574 | `fugitive#LogCommand()` |
| `:Ge` / `:Gedit` | plugin:577 | `fugitive#Open()` |
| `:Gpedit` | plugin:579 | `fugitive#Open()` |
| `:Gsplit` | plugin:580 | `fugitive#Open()` |
| `:Gvsplit` | plugin:581 | `fugitive#Open()` |
| `:Gtabedit` | plugin:582 | `fugitive#Open()` |
| `:Gdrop` | plugin:583 | `fugitive#DropCommand()` |
| `:Gr` / `:Gread` | plugin:588 | `fugitive#ReadCommand()` |
| `:Gdiffsplit` | plugin:590 | `fugitive#Diffsplit()` |
| `:Ghdiffsplit` | plugin:591 | `fugitive#Diffsplit()` |
| `:Gvdiffsplit` | plugin:592 | `fugitive#Diffsplit()` |
| `:Gw` / `:Gwrite` | plugin:594 | `fugitive#WriteCommand()` |
| `:Gwq` | plugin:596 | `fugitive#WqCommand()` |
| `:GRemove` | plugin:598 | `fugitive#RemoveCommand()` |
| `:GUnlink` | plugin:599 | `fugitive#UnlinkCommand()` |
| `:GDelete` | plugin:600 | `fugitive#DeleteCommand()` |
| `:GMove` | plugin:601 | `fugitive#MoveCommand()` |
| `:GRename` | plugin:602 | `fugitive#RenameCommand()` |
| `:GBrowse` | plugin:630 | `fugitive#BrowseCommand()` |

### 6.2 Legacy Commands (removidos, placeholder de error)

| Comando | Estado |
|---|---|---|
| `:Gremove` | Error message si `g:fugitive_legacy_commands` no está set |
| `:Gdelete` | Error message si `g:fugitive_legacy_commands` no está set |
| `:Gmove` | Error message si `g:fugitive_legacy_commands` no está set |
| `:Grename` | Error message si `g:fugitive_legacy_commands` no está set |
| `:Gbrowse` | Error message si `g:fugitive_legacy_commands` no está set |

---

## 7. Acoplamiento Crítico Detectado

### 7.1 Dependencias Circulares

**No se detectaron dependencias circulares directas.** El flujo es unidireccional:
```
plugin/fugitive.vim  →  autoload/fugitive.vim (fugitive#*)
                              ↓
                         (s:* functions internas)
```

Sin embargo, hay **acoplamiento fuerte** entre:

1. **Status ↔ Temp files**: `fugitive#DidChange()` (status) usa `s:temp_files` (temp files) y viceversa
2. **Git execution ↔ Status**: `s:RunFinished()` llama `fugitive#DidChange()` que dispara reload del status
3. **File API ↔ Git**: `fugitive#Find()` usa `s:Tree()` que lee archivos del git dir

### 7.2 Funciones Mutando Estado Global

| Función | Estado que muta | Impacto |
|---|---|---|
| `fugitive#DidChange()` | `g:fugitive_did_change_at`, `s:head_cache`, `s:config`, `s:config_prototype`, `s:remote_headers` | **Alto** — invalida todos los caches |
| `fugitive#ExpireConfig()` | `s:config`, `s:config_prototype` | **Medio** — invalida config cache |
| `s:ExpireStatus()` | `s:head_cache`, `s:last_time`, `s:last_times` | **Medio** — invalida HEAD cache |
| `s:RunSave()` | `s:temp_files` | **Alto** — registra temp file de job |
| `s:RunFinished()` | `g:_fugitive_last_job`, `s:temp_files` | **Alto** — actualiza último resultado |
| `s:Tree()` (plugin) | `s:worktree_for_dir`, `s:dir_for_worktree` | **Bajo** — cache de worktree |
| `FugitiveCommonDir()` | `s:commondirs` | **Bajo** — cache de commondir |
| `FugitiveActualDir()` | `s:resolved_git_dirs` | **Bajo** — cache de git dir |
| `fugitive#GitVersion()` | `s:git_versions` | **Bajo** — cache de versión |
| `s:RunEdit()` | `s:edit_jobs`, `g:fugitive_event`, `g:fugitive_result` | **Alto** — estado de edición interactiva |

### 7.3 Variables Compartidas entre Secciones

| Variable | Secciones que la leen | Secciones que la escriben |
|---|---|---|
| `s:temp_files` | Temp files, :Git, Status, Maps | :Git, Temp files |
| `s:head_cache` | Git config, Status | Status, Git config |
| `s:config` | Git config, :Git, GBrowse, Status | Git config, fugitive#DidChange |
| `g:fugitive_event` | plugin (FugitiveGitDir), Status, :Git | Status, :Git |
| `g:fugitive_result` | Status, :Git, GBrowse | Status, :Git |
| `g:_fugitive_last_job` | Temp files, :Git | :Git |
| `b:git_dir` | plugin, autoload (todas) | plugin (FugitiveDetect), autoload |
| `b:fugitive_type` | Buffer auto-commands, Maps, Temp files | Buffer auto-commands |

---

## 8. Async / Jobs Architecture

### 8.1 Compatibilidad

| Runtime | Funciones usadas | Línea |
|---|---|---|
| Neovim | `jobstart()`, `chansend()`, `chanclose()`, `jobwait()` | autoload:391-404 |
| Vim 8+ | `job_start()`, `ch_close_in()`, `job_status()`, `ch_status()` | autoload:405-424 |
| Fallback | `system()` con redirección a archivo temporal | autoload:425-444 |

### 8.2 Flujo de Ejecución

```
fugitive#Command()  →  s:UserCommandList()  →  s:JobExecute()
                                                    ↓
                                       ┌────────────┼────────────┐
                                       ↓            ↓            ↓
                                  Neovim?       Vim 8+?      Fallback
                                  jobstart     job_start     system()
                                       ↓            ↓            ↓
                                  s:JobNvimExit  s:JobVimExit  directo
                                       ↓            ↓            ↓
                                  s:RunFinished ←─┴────────────┘
                                       ↓
                              fugitive#DidChange()
                                       ↓
                              User FugitiveChanged
```

### 8.3 Callbacks de Job

| Callback | Función | Línea | Propósito |
|---|---|---|---|
| `on_exit` (Vim) | `s:JobVimExit()` | 369 | Lee stdout/stderr de archivos temporales |
| `on_exit` (Neovim) | `s:JobNvimExit()` | 380 | Lee stdout/stderr bufferizados |
| `on_stdout` | `s:RunReceive()` | 3487 | Recibe stdout en tiempo real |
| `on_stderr` | `s:RunReceive()` | 3487 | Recibe stderr en tiempo real |
| `exit_cb` | `s:RunExit()` | 3550 | Captura exit status |
| `close_cb` | `s:RunClose()` | 3558 | Finaliza job, escribe buffer |

---

## 9. URL Scheme `fugitive://`

### 9.1 Formato

```
fugitive://{git_dir}//{commit}{file}
```

Ejemplos:
- `fugitive:///home/proj/.git//HEAD:README.md` — archivo en HEAD
- `fugitive:///home/proj/.git//:0:src/main.py` — archivo en stage 0
- `fugitive:///home/proj/.git//a1b2c3d4:/src/main.py` — archivo en commit específico

### 9.2 Pattern de Parseo

```vim
s:dir_commit_file = '\c^fugitive://\%(/[^/]\@=\)\=\([^?#]\{-1,\}\)//\%(\(\x\{40,\}\|[0-3]\)\(/[^?#]*\)\=\)\=$'
```

### 9.3 Funciones de File API Virtual

Todas las funciones `fugitive#*` del File API (sección 6) interceptan URLs `fugitive://` y las traducen a operaciones Git:

- `fugitive#readfile()` → `git cat-file blob`
- `fugitive#writefile()` → `git hash-object -w` / `git update-index`
- `fugitive#isdirectory()` → `git ls-tree`
- `fugitive#glob()` → `git ls-tree` pattern matching

---

## 10. Configuration Variables

| Variable | Default | Descripción |
|---|---|---|
| `g:loaded_fugitive` | (auto) | Plugin guard |
| `g:fugitive_no_maps` | 0 | Deshabilita key mappings automáticos |
| `g:fugitive_legacy_commands` | 0 | Habilita comandos deprecated en minúsculas |
| `g:fugitive_dynamic_colors` | 1 | Colores de hash de commit |
| `g:fugitive_git_executable` | `'git'` | Path/args del binario git |
| `g:fugitive_git_command` | (auto) | Comando git alternativo |
| `g:fugitive_focus_gained` | `!has('win32')` | Auto-reload en FocusGained |
| `g:fugitive_diffsplit_directional_fit` | 1 | Dirección del diff split |

---

## 11. Riesgos para Refactorización

### 11.1 Alto Riesgo

1. **`fugitive#DidChange()`** — Invalida 5 caches simultáneamente. Cualquier refactorización debe preservar este comportamiento.
2. **`s:temp_files`** — Registry compartido entre ejecución de jobs, temp buffers, y status. Es el punto de acoplamiento más fuerte.
3. **`g:fugitive_event` / `g:fugitive_result`** — Estado global de eventos. Usado por `FugitiveGitDir()`, `fugitive#Result()`, y autocommands.
4. **`b:git_dir`** — Variable de buffer que determina si fugitive está activo. Seteada por múltiples funciones.

### 11.2 Medio Riesgo

1. **`s:head_cache`** — Cache de HEAD compartido entre config y status.
2. **`s:config` / `s:config_prototype`** — Cache de configuración con prototype pattern.
3. **`s:worktree_for_dir` / `s:dir_for_worktree`** — Bidireccional worktree↔dir mapping.
4. **`s:RunEdit()`** — Estado de edición interactiva con `s:edit_jobs`.

### 11.3 Bajo Riesgo

1. **Caches de un solo writer** (`s:git_versions`, `s:executables`, `s:commondirs`, `s:resolved_git_dirs`)
2. **Patterns de regex** (`s:file_pattern`, `s:section_pattern`, etc.) — constantes
3. **Variables de window** (`w:fugitive_diff_restore`, `w:fugitive_leave`) — scope limitado

---

## 12. Recomendaciones para Fase 2 (Migración)

1. **Mantener `plugin/fugitive.vim` intacto** como capa de compatibilidad — todas las funciones `Fugitive*` son API pública.
2. **Extraer por secciones** en el orden de menor acoplamiento a mayor:
   - Statusline → Folding → Utility → File API → Git config → Remotes → Quickfix → Diff → Blame → Browse → Grep/Log → Commands → Status → Git execution
3. **Preservar el registry `s:temp_files`** como módulo compartido — es el núcleo del sistema async.
4. **Mantener `fugitive#DidChange()`** como función coordinadora de invalidación de caches.
5. **No separar `s:Tree()` del plugin** — tiene coupling bidireccional con `FugitiveExtractGitDir()`.
