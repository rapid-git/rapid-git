# rapid-git

![rapid-git Demo](https://raw.githubusercontent.com/rapid-git/rapid-git/master/images/demo.gif)

rapid-git provides shortcuts for often-used git commands which aim to make your daily git use more efficient by typing less.

rapid-git enables you to interact with files and branches using numbers (called indexes). Indexes represent the files that `git status` or branches that `git branch` prints on the screen. When interacting with files you may define ranges using the [numbers and dots notation](#specifying-indexes).

The concept behind rapid-git was introduced by [Alexander Groß](https://github.com/agross) in his repository [git_shizzle](https://github.com/agross/git_shizzle). In contrast to this repository, which uses shell, he implemented his project using Ruby. If you are interested, please have a look at his project too.

## Prerequisites and installation

There are a few prerequisites worth mentioning:

* Your bash version needs to be at least v4.0.0. Use the command `bash --version` to check yours.
* If you use zsh, be aware that we tested the script with v5.0.2 and v5.1.1. Use `zsh --version` to check yours.
* If you use `Mac`, make sure, that you have `gnu-sed` installed. The easiest way is to use [homebrew](http://brew.sh/) to install it: `brew install gnu-sed --with-default-names`. For more extensive instructions on how to install GNU commmand line tools on `Mac`, please refer to this [blog post](https://www.topbug.net/blog/2013/04/14/install-and-use-gnu-command-line-tools-in-mac-os-x/).

Let's install rapid-git:

1. Start with cloning this repository:
   ```bash
   git clone https://github.com/rapid-git/rapid-git.git
   ```

1. Add *rapid-git.sh* to *.bashrc* or *.zshrc*:
   ```bash
   source path/to/rapid-git.sh
  ```

1. At this point rapid-git should already work, but you may also add *alias.rapid-git.sh* to get some default aliases.
   ```bash
   source path/to/alias.rapid-git.sh
   ```

**Note for Windows users:** There is a certain trick for Windows users, who wish to create files such as *.bashrc* via the Windows Explorer. When typing the file name, do it as follows without defining a file extension: `.bashrc.`

## Commands

### Specifying Indexes

Indexes always refer to the position of a file, directory or branch in the output of `git status` and `git branch`. Indexes start at **1** not at **0**. Ranges can be defined using numbers and dots notation. There are the following notations available:

| notation           | description                                     |
| :----------------- |:----------------------------------------------- |
| `#`                | select a single list entry                      |
| `..`               | select all list entries                         |
| `..#` e.g. `..5`   | select the first entry up to the fifth one      |
| `#..` e.g. `3..`   | select the third entry up to the last one       |
| `#..#` e.g. `4..7` | select the fourth entry up to the seventh entry |

* [Index commands](#index-commands) support indexes or ranges.
* [Index commands](#index-commands) allow multiple arguments to be passed.
* [Branch commands](#branch-commands) only support a single index.

### Index Commands

These commands relate to the git index and the working copy.

- [rapid status](#rapid-status)
- [rapid track](#rapid-track)
- [rapid stage](#rapid-stage)
- [rapid unstage](#rapid-unstage)
- [rapid drop](#rapid-drop)
- [rapid remove](#rapid-remove)
- [rapid diff](#rapid-diff)

### Branch Commands

These commands relate to git branches.

- [rapid branch [-d | -D | -a | -r]](#rapid-branch)
- [rapid checkout](#rapid-checkout)
- [rapid merge](#rapid-merge)
- [rapid rebase [-c | --continue | -a | --abort]](#rapid-rebase)

---

### rapid status

- Show **staged files** with index
- Show **unstaged files** with index
- Show **untracked files** with index
- Show **unmerged files** with index *(no other rapid command works with these indexes yet)*

### rapid track

- Track one or multiple files by [index or range](#specifying-indexes)
- Equivalent to `git add`, allows passing arbitrary options
- Indexes based on **untracked files** and folders of `rapid status`

### rapid stage

- Stage one or multiple files by [index or range](#specifying-indexes)
- Equivalent to `git add`, allows passing arbitrary options (e.g. `--patch`)
- Indexes are based on **unstaged files** of `rapid status`

### rapid unstage

- Unstage one or multiple files by [index or range](#specifying-indexes)
- Equivalent to `git reset HEAD`, allows passing arbitrary options (e.g. `--patch`)
- Indexes are based on **staged files** of `rapid status`

### rapid drop

- Drop unstaged changes of one or multiple files by [index or range](#specifying-indexes)
- Equivalent to `git checkout`, allows passing arbitrary options (e.g. `--patch`)
- Indexes are based on **unstaged files** of `rapid status`

### rapid remove

- Remove one or multiple files by [index or range](#specifying-indexes)
- Equivalent to `rm -rf`, allows passing arbitrary `rm` options
- Indexes are based on **untracked files** of `rapid status`
- When removing a directory, this command tries to remove sub-level files and directories, too

### rapid diff

- Show the diff of one or multiple files
- Equivalent to `git diff`, allows passing arbitrary options options (e.g. `--word-diff`)
- Indexes are based on **unstaged files** of `rapid status` when using no additional option
- Indexes are based on **staged files** of `rapid status` when using `--cached` or `--staged` as the first option

### rapid branch

- Show all local branches
- Mark the current branch
- Display the index of each branch
- Show all remote branches by using the option `-r`
- Show all branches by using the option `-a`
- Delete a branch by using the option `-d`
- Force-delete a branch by using the option `-D`
- Using the options `-r`, `-a`, `-d` and `-D` requires to pass a branch along by using its index
- Indexes are based on `git branch | rapid branch`

### rapid checkout

- Checkout a branch by using its index
- Indexes are based on `git branch | rapid branch`

### rapid merge

- Merge a branch by using its index
- Indexes are based on `git branch | rapid branch`

### rapid rebase

- Rebase a branch by using its index
- Indexes are based on `git branch | rapid branch`
- Continue rebasing by using the option `-c | --continue`
- Abort rebasing by using the option `-a | --abort`

## Default aliases

| alias         | description         |
| ------------- |:--------------------|
| `rst`         | `rapid status`      |
| `rt`          | `rapid track`       |
| `ra`          | `rapid stage`       |
| `ru`          | `rapid unstage`     |
| `rdr`         | `rapid drop`        |
| `rr`          | `rapid remove`      |
| `rd`          | `rapid diff`        |
| `rb`          | `rapid branch`      |
| `rco`         | `rapid checkout`    |
| `rme`         | `rapid merge`       |
| `rre`         | `rapid rebase`      |

## Color configuration

### Disabling colors

rapid-git colorizes output by default unless output is being redirected or if it
is invoked as part of a pipeline. You can explicitly disable output coloring by
setting the variable `RAPID_GIT_COLORS` to a falsey value (`0`, `false`, `off`).
You do not need to export the value.

Example:
```sh
$ RAPID_GIT_COLORS=off
```

### Custom color values

Color values are either determined by corresponding git colors (e.g. unstaged
changes are colored
[like `git status` would - search for `color.status.<slot>`](https://git-scm.com/docs/git-config)).
You may override some or all of the color values by defining `RAPID_GIT_COLORS`
as an associative array. The following array subscripts are evaluated by
rapid-git:

| subscript              | description                                                    | git config               | default color     |
| :--------------------- | :------------------------------------------------------------- | :----------------------- | :---------------- |
| `reset`                | reset color back to defaults                                   |                          | (invisible)       |
| `branch`               | branch names                                                   | `color.branch.local`     | cyan              |
| `branch_index`         | branch indexes                                                 |                          | yellow            |
| `branch_current`       | current branch name                                            | `color.branch.current`   | bold cyan         |
| `branch_current_index` | current branch index                                           |                          | bold yellow       |
| `status_index`         | index of `rapid status`                                        |                          | bold yellow       |
| `status_staged`        | staged files                                                   | `color.status.added`     | bold red          |
| `status_unstaged`      | unstaged files                                                 | `color.status.changed`   | bold green        |
| `status_untracked`     | untracked files                                                | `color.status.untracked` | bold blue         |
| `status_unmerged`      | unmerged files                                                 | `color.status.changed`   | bold magenta      |
| `mark_stage`           | color of symbol printed in front of files about to be staged   |                          | yellow            |
| `mark_reset`           | color of symbol printed in front of files about to be unstaged |                          | yellow            |
| `mark_drop`            | color of symbol printed in front of files about to be removed  |                          | cyan              |
| `mark_error`           | color of symbol for errors (e.g. nonexistent index)            |                          | bold red          |


**Defining colors on Windows will most certainly speed up your rapid-git
invocations because we can omit creating a couple of git processes.**

Example:

```sh
declare -A RAPID_GIT_COLORS
RAPID_GIT_COLORS[status_index]='\e[0;34m' # blue
RAPID_GIT_COLORS[branch_index]='\e[1;31m' # bright red
# etc.

# zsh users may use builtin colors support.
autoload -U colors && colors
typeset -A RAPID_GIT_COLORS
RAPID_GIT_COLORS[status_index]=$fg[blue]
RAPID_GIT_COLORS[branch_index]=$fg_bold[red]
```

### Debugging colors

The `rapid colors` command displays your current color configuration.

![rapid-git colors](https://raw.githubusercontent.com/rapid-git/rapid-git/master/images/colors.png)

## Authors

### Philip Tober

+ [GitHub](https://github.com/philiptober)
+ [Twitter](https://twitter.com/philiptober)
+ [Blog](http://philiptober.wordpress.com/)

### Alexander Groß

+ [GitHub](https://github.com/agross)
+ [Twitter](https://twitter.com/agross)
+ [Blog](http://therightstuff.de/)

### Gregor Woiwode

+ [GitHub](https://github.com/GregOnNet)
+ [Twitter](https://twitter.com/gregonnet)
+ [Blog](http://www.woiwode.info/)

## License
rapid-git is under MIT license - http://www.opensource.org/licenses/mit-license.php
