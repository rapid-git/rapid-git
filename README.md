# rapid-git

![rapid-git Demo](https://raw.githubusercontent.com/agross/rapid-git/master/demo.gif)

It provides multiple functions, which aim to use git in a more efficient way. To do that, rapid-git enables you to interact with files and branches using numbers. Each number represent the position/index of a file or branch inside a list like `git status` and `git branch`. It is also possible to define ranges using numbers and dots, when interacting with files.

The concept behind rapid-git was introduced by [Alexander Groß](https://github.com/agross) in his repository [git_shizzle](https://github.com/agross/git_shizzle). In contrast to this repository, which uses shell/bash, he implemented his project using Ruby. If you are interested, please have a look at his project too.

## Prerequisites and installation

There are only 2 requisites worth mentioning. Firstly, your bash version needs to equal or be above v4.0.0. Use the command `bash --version` to read out yours. Secondly, use Cygwin on Windows or use a Mac. rapid-git uses the same colors that are configured for standard git commands.

Now lets start with adding rapid-git:

1. Start with cloning this repository: 
    <pre>https://github.com/philiptober/rapid-git.git</pre>
2. Add rapid-git.sh to *.bash_profile* or *.profile* like:
    <pre>source path/to/this/file/rapid-git.sh</pre>
3. At this point rapid-git should already work, but you may also add alias.rapid-git.sh to get some default aliases. Simply mirror the second step again to do that

Also some pointers:
* If neither *.bash_profile* nor *.profile* exist, create them yourself
* Using Cygwin, *.profile* needs to be called via `cygwin/bin/sh.exe --login -i` or it will not be applied
* There is a certain trick for Windows users, who wish to create files such as *.profile* via the Windows Explorer. When typing the file name, do it like that without defining any file type:
    <pre>.profile.</pre>

## Commands

Some commands only depend on indexes while other also depend on ranges. Indexes always refer to the position of a file, folder or branch inside the output lists of `git status` and `git branch`. The index count starts with **1** not **0**. Ranges can be defined using index and dots. There are the following schemata available:

| schema / argument  | description                                    |
| ------------------ |:---------------------------------------------- |
| `..`               | select all list entries                        |
| `..#` like `..5`   | select the first entry up to the fifth one     |
| `#..` like `3..`   | select the third entry up to the last one      |
| `#..#` like `4..7` | select the forth entry up to the seventh entry |

Commands targeting files and folders allow multiple arguments to be passed.

### Overview

- rapid status
- rapid track
- rapid stage [-p | --patch]
- rapid unstage
- rapid drop
- rapid remove
- rapid diff [-c]
- rapid branch [-d | -D | -a | -r]
- rapid checkout
- rapid merge
- rapid rebase [-c | --continue | -a | --abort]

### rapid status

- Show staged content suffixed by index
- Show unstaged content suffixed by index
- Show unstaged content suffixed by index
- Show unmerged content suffixed by index (no other rapid command works with these indexes yet)

### rapid track

- Track one or multiple files and folders by index or range
- Indexes based on untracked files and folders of `git status`

### rapid stage

- Stage one or multiple files by index or range
- Indexes are based on unstaged files of `git status`
- Use the **-p | --patch** just like you use it with `git add`

### rapid unstage

- Unstage one or multiple files by index or range
- Indexes are based on staged files of `git status`

### rapid drop

- Drop not yet commited changes of one or multiple files by index or range
- Indexes are based on unstaged files of `git status`

### rapid remove

- Remove one or multiple files and folders by index or range
- Indexes are based on untracked files and folders of `git status`
- This command tries to remove sub-level files and folders too, when trying to remove a folder

### rapid diff

- Show the diff of one or multiple files
- Indexes are based on unstaged files of `git status`, when using no additional option
- Indexes are based on staged files of `git status`, when using the option **-c**

### rapid branch

- Show all local branches
- Mark the current branch
- Display the index of each branch
- Show all remote branches by using the option **-r**
- Show all branches by using the option **-a**
- Delete a branch by using the option **-d**
- Force-delete a branch by using the option **-D**
- Using the options **-r**, **-a**, **-d** and **-D** requires to pass a branch along by using its index
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
- Continue rebasing by using the option **-c | --continue**
- Abort rebasing by using the option **-a | --abort**

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

## Additional Information

### Author

**Philip Tober**

+ [Github](https://github.com/philiptober)
+ [Twitter](https://twitter.com/philiptober)
+ [Wordpress](http://philiptober.wordpress.com/)

### Credits

Thank you [Alexander Groß](https://github.com/agross) for creating [git_shizzle](https://github.com/agross/git_shizzle). It made working with git a lot easier.

### Copyright
Copyright © 2015 [Philip Tober](https://twitter.com/philiptober).

### License 
**rapid-git** is under MIT license - http://www.opensource.org/licenses/mit-license.php
