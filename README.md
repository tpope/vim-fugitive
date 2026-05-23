# ghostgit.nvim

ghostgit.nvim is a Vim/Neovim plugin for Git integration — a modern fork of
[vim-fugitive](https://github.com/tpope/vim-fugitive) by Tim Pope. It provides
the same `:G*` commands and `Fugitive*` API compatibility, with refactored
internals and Neovim-friendly improvements.

The crown jewel of ghostgit is `:Git` (or just `:G`), which calls any
arbitrary Git command. If you know how to use Git at the command-line, you
know how to use `:Git`. It's vaguely akin to `:!git` but with numerous
improvements:

- The default behavior is to directly echo the command's output. Quiet
  commands like `:Git add` avoid the dreaded "Press ENTER or type command to
  continue" prompt.
- `:Git commit`, `:Git rebase -i`, and other commands that invoke an editor do
  their editing in the current Vim instance.
- `:Git diff`, `:Git log`, and other verbose, paginated commands have their
  output loaded into a temporary buffer. Force this behavior for any command
  with `:Git --paginate` or `:Git -p`.
- `:Git blame` uses a temporary buffer with maps for additional triage. Press
  enter on a line to view the commit where the line changed, or `g?` to see
  other available maps. Omit the filename argument and the currently edited
  file will be blamed in a vertical, scroll-bound split.
- `:Git mergetool` and `:Git difftool` load their changesets into the quickfix
  list.
- Called with no arguments, `:Git` opens a summary window with dirty files and
  unpushed and unpulled commits. Press `g?` to bring up a list of maps for
  numerous operations including diffing, staging, committing, rebasing, and
  stashing.
- This command (along with all other commands) always uses the current
  buffer's repository, so you don't need to worry about the current working
  directory.

Additional commands are provided for higher level operations:

- View any blob, tree, commit, or tag in the repository with `:Gedit` (and
  `:Gsplit`, etc.). For example, `:Gedit HEAD~3:%` loads the current file as
  it existed 3 commits ago.
- `:Gdiffsplit` (or `:Gvdiffsplit`) brings up the staged version of the file
  side by side with the working tree version. Use Vim's diff handling
  capabilities to apply changes to the staged version, and write that buffer
  to stage the changes. You can also give an arbitrary `:Gedit` argument to
  diff against older versions of the file.
- `:Gread` is a variant of `git checkout -- filename` that operates on the
  buffer rather than the file itself. This means you can use `u` to undo it
  and you never get any warnings about the file changing outside Vim.
- `:Gwrite` writes to both the work tree and index versions of a file, making
  it like `git add` when called from a work tree file and like `git checkout`
  when called from the index or a blob in history.
- `:Ggrep` is `:grep` for `git grep`. `:Glgrep` is `:lgrep` for the same.
- `:GMove` does a `git mv` on the current file and changes the buffer name to
  match. `:GRename` does the same with a destination filename relative to the
  current file's directory.
- `:GDelete` does a `git rm` on the current file and simultaneously deletes
  the buffer. `:GRemove` does the same but leaves the (now empty) buffer
  open.
- `:GBrowse` to open the current file on the web frontend of your favorite
  hosting provider, with optional line range (try it in visual mode). Built-in
  support is provided for GitHub, GitLab, and Bitbucket. Custom providers can
  be registered via `ghostgit#browse#RegisterProvider()`.

Add `%{FugitiveStatusline()}` or `%{GhostgitStatusline()}` to `'statusline'`
to get an indicator with the current branch in your statusline.

For more information, see `:help ghostgit`.

## Screencasts

- [A complement to command-line git](http://vimcasts.org/e/31)
- [Working with the git index](http://vimcasts.org/e/32)
- [Resolving merge conflicts with vimdiff](http://vimcasts.org/e/33)
- [Browsing the git object database](http://vimcasts.org/e/34)
- [Exploring the history of a git repository](http://vimcasts.org/e/35)

## Installation

Install using your favorite package manager, or use Vim's built-in package
support:

    mkdir -p ~/.vim/pack/plugins/start
    cd ~/.vim/pack/plugins/start
    git clone https://github.com/your-org/ghostgit.nvim.git
    vim -u NONE -c "helptags ghostgit.nvim/doc" -c q

For Neovim with lazy.nvim:

    { 'your-org/ghostgit.nvim' }

## API Compatibility

ghostgit.nvim maintains full backward compatibility with vim-fugitive's public
API. All `Fugitive*` functions work as documented:

- `FugitiveGitDir([bufnr])` — returns the Git dir for a buffer
- `FugitiveReal(url)` — converts a `ghostgit://` URL to a real filesystem path
- `FugitiveFind(spec)` — resolves a ghostgit object to a buffer name
- `FugitiveHead([truncate], [git_dir])` — returns current branch name
- `FugitiveExecute(args, [git_dir], [callback])` — runs Git asynchronously
- `FugitiveResult()` — returns result of the most recent `:Git` command
- `FugitiveDidChange([bufnr])` — triggers `FugitiveChanged` event
- `FugitiveConfig()`, `FugitiveConfigGet()`, `FugitiveConfigGetAll()`, `FugitiveConfigGetRegexp()` — config access
- `FugitiveRemoteUrl()`, `FugitiveRemote()` — remote URL parsing
- `FugitiveShellCommand()` — builds a Git command string
- `FugitiveStatusline()` — statusline indicator

The native `Ghostgit*` API is also available with identical functionality.

## Configuration

- `g:ghostgit_no_maps` — set to 1 to disable automatic key mappings
- `g:ghostgit_blame_conceal` — set to 0 to disable conceal in blame buffers

## FAQ

> What happened to the dispatch.vim backed asynchronous `:Gpush` and
> `:Gfetch`?

This behavior was divisive, confusing, and complicated inputting passwords, so
it was removed. Use `:Git! push` to use ghostgit's own asynchronous
execution, or retroactively make `:Git push` asynchronous by pressing
`CTRL-D`.

> Why am I getting `core.worktree is required when using an external Git dir`?

Git generally sets `core.worktree` for you automatically when necessary, but
if you're doing something weird, or using a third-party tool that does
something weird, you may need to set it manually:

    git config core.worktree "$PWD"

This may be necessary even when simple `git` commands seem to work fine
without it.

> So I have a symlink and...

Stop. Just stop. If Git won't deal with your symlink, then ghostgit won't
either. Consider using a [plugin that resolves
symlinks](https://github.com/aymericbeaumet/symlink.vim), or even better,
using fewer symlinks.

## Contributing

### Testing

Tests are written using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).
To run tests locally, ensure you have `plenary.nvim` in your runtimepath and run:

    make test

For CI, we use GitHub Actions to run tests and linting on every push.

## License

Original vim-fugitive Copyright (c) Tim Pope. Distributed under the same
terms as Vim itself. See `:help license`.

ghostgit.nvim modifications are distributed under the same terms.
