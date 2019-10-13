# fugitive.vim

I'm not going to lie to you; fugitive.vim may very well be the best
Git wrapper of all time.  Check out these features:

Bring up an enhanced version of `git status` with `:G` (also known as
`:Gstatus`).  Press `g?` to bring up a list of maps for numerous operations
including diffing, staging, committing, rebasing, and stashing.

View any blob, tree, commit, or tag in the repository with `:Gedit` (and
`:Gsplit`, `:Gvsplit`, `:Gtabedit`, ...).  Edit a file in the index and
write to it to stage the changes.  Use `:Gdiffsplit` to bring up the staged
version of the file side by side with the working tree version and use
Vim's diff handling capabilities to stage a subset of the file's
changes.

Commit, merge, and rebase with `:Gcommit`, `:Gmerge`, and `:Grebase`, using
the current Vim instance to edit commit messages and the rebase todo list.
Use `:Gpush`, `:Gfetch`, and `:Gpull` to send and retrieve upstream changes.

`:Gblame` brings up an interactive vertical split with `git blame`
output.  Press enter on a line to edit the commit where the line
changed, or `o` to open it in a split.  When you're done, use `:Gedit`
in the historic buffer to go back to the work tree version.

`:Gmove` does a `git mv` on a file and simultaneously renames the
buffer.  `:Gdelete` does a `git rm` on a file and simultaneously deletes
the buffer.

Use `:Ggrep` to search the work tree (or any arbitrary commit) with
`git grep`, skipping over that which is not tracked in the repository.
`:Gclog` and `:Gllog` load all previous commits into the quickfix or location
list.  Give them a range (e.g., using visual mode and `:'<,'>Gclog`) to
iterate over every change to that portion of the current file.

`:Gread` is a variant of `git checkout -- filename` that operates on the
buffer rather than the filename.  This means you can use `u` to undo it
and you never get any warnings about the file changing outside Vim.
`:Gwrite` writes to both the work tree and index versions of a file,
making it like `git add` when called from a work tree file and like
`git checkout` when called from the index or a blob in history.

Use `:Gbrowse` to open the current file on the web front-end of your favorite
hosting provider, with optional line range (try it in visual mode).  Plugins
are available for popular providers such as [GitHub][rhubarb.vim],
[GitLab][fugitive-gitlab.vim], [Bitbucket][fubitive.vim],
[Gitee][fugitive-gitee.vim], and [Pagure][pagure].

[rhubarb.vim]: https://github.com/tpope/vim-rhubarb
[fugitive-gitlab.vim]: https://github.com/shumphrey/fugitive-gitlab.vim
[fubitive.vim]: https://github.com/tommcdo/vim-fubitive
[fugitive-gitee.vim]: https://github.com/linuxsuren/fugitive-gitee.vim
[pagure]: https://github.com/FrostyX/vim-fugitive-pagure

Add `%{FugitiveStatusline()}` to `'statusline'` to get an indicator
with the current branch in your statusline.

Last but not least, there's `:Git` for running any arbitrary command.

For more information, see `:help fugitive`.

## Screencasts

* [A complement to command line git](http://vimcasts.org/e/31)
* [Working with the git index](http://vimcasts.org/e/32)
* [Resolving merge conflicts with vimdiff](http://vimcasts.org/e/33)
* [Browsing the git object database](http://vimcasts.org/e/34)
* [Exploring the history of a git repository](http://vimcasts.org/e/35)

## Installation

Install using your favorite package manager, or use Vim's built-in package support:
	
    mkdir -p ~/.vim/pack/tpope/start
    cd ~/.vim/pack/tpope/start
    git clone https://tpope.io/vim/fugitive.git
    vim -u NONE -c "helptags fugitive/doc" -c q

## FAQ

> Why can't I enter my password when I `:Gpush`?

It is highly recommended to use SSH keys or [credentials caching][] to avoid
entering your password on every upstream interaction.  If this isn't an
option, the official solution is to use the `core.askPass` Git option to
request the password via a GUI.  Fugitive will configure this for you
automatically if you have `ssh-askpass` or `git-gui` installed; otherwise it's
your responsibility to set this up.

As an absolute last resort, you can invoke `:Git --paginate push`.  Fugitive
recognizes the pagination request and fires up a `:terminal`, which allows for
interactive password entry.

[credentials caching]: https://help.github.com/en/articles/caching-your-github-password-in-git

## Self-Promotion

Like fugitive.vim? Follow the repository on
[GitHub](https://github.com/tpope/vim-fugitive) and vote for it on
[vim.org](http://www.vim.org/scripts/script.php?script_id=2975).  And if
you're feeling especially charitable, follow [tpope](http://tpo.pe/) on
[Twitter](http://twitter.com/tpope) and
[GitHub](https://github.com/tpope).

## License

Copyright (c) Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
