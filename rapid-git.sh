#!/bin/sh

function rapid {

  # Temporary hack until an installer function is written.
  local sedE='r'
  if [[ "$(uname -s)" == 'Darwin' ]]; then
    sedE='E'
  fi

  local function_prefix='__rapid_'
  local command_prefix="${function_prefix}_"
  local -a rapid_functions

  function __rapid_zsh {
    [[ -n "$ZSH_VERSION" ]]
  }

  function __rapid_functions {
    local function_prefix=$1

    if ! __rapid_zsh; then
      # Bash uses declare to return all functions.
      IFS=$'\n'
      rapid_functions=($(declare -F | cut --delimiter=' ' --fields=3 | /usr/bin/grep "$function_prefix"))
    else
      # zsh has a function associative array.
      local -a all_functions
      all_functions=(${(ok)functions})
      rapid_functions=(${${(M)all_functions:#$function_prefix*}})
    fi
  }

  function __rapid_cleanup {
    __rapid_functions "$function_prefix"

    for fun in $rapid_functions; do
      unset -f "$fun"
    done
  }

  local c_end
  local fg_black fg_red fg_green fg_yellow fg_blue fg_magenta fg_cyan fg_white
  local fg_b_black fg_b_red fg_b_green fg_b_yellow fg_b_blue fg_b_magenta fg_b_cyan fg_b_white

  function __rapid_init_colors {
    # Commented colors are not used. Speeds up things a bit on Windows where process creation is expensive.
    c_end="$(git config --get-color "" "reset")"

    # fg_black="$(git config --get-color "" "black")"
    # fg_red="$(git config --get-color "" "red")"
    # fg_green="$(git config --get-color "" "green")"
    fg_yellow="$(git config --get-color "" "yellow")"
    # fg_blue="$(git config --get-color "" "blue")"
    # fg_magenta="$(git config --get-color "" "magenta")"
    fg_cyan="$(git config --get-color "" "cyan")"
    #fg_white="$(git config --get-color "" "white")"

    # fg_b_black="$(git config --get-color "" "bold black")"
    fg_b_red="$(git config --get-color "" "bold red")"
    # fg_b_green="$(git config --get-color "" "bold green")"
    fg_b_yellow="$(git config --get-color "" "bold yellow")"
    # fg_b_blue="$(git config --get-color "" "bold blue")"
    fg_b_magenta="$(git config --get-color "" "bold magenta")"
    fg_b_cyan="$(git config --get-color "" "bold cyan")"
    # fg_b_white="$(git config --get-color "" "bold white")"
  }

  function __rapid_command_not_found {
    local requested_command=$1
    local known_commands

    __rapid_functions "$command_prefix"

    if ! __rapid_zsh; then
      known_commands="$(printf '  %s\n' "${rapid_functions[@]/#$command_prefix/}")"
    else
      known_commands="$(print -l ${rapid_functions/#$command_prefix/  })"
    fi

    echo -e "Unknown command: ${1:-none}\n\nAvailable commands:\n$known_commands" 1>&2
    return 1
  }

  function __rapid_query {
    local target=$1
    local getLine=' !d'
    local counter
    local end
    local entry

    for var in ${@:2}; do
      count=""
      end=""

      if [[ $var =~ ^[1-9][0-9]*\.\.[1-9][0-9]*$ ]]; then
        counter="$(sed 's/\.\.[1-9][0-9]*$//g' <<< "$var")"
        end="$(sed 's/^[1-9][0-9]*\.\.//g' <<< "$var")"

      elif [[ $var =~ ^[1-9][0-9]*\.\.$ ]];then
        counter="$(sed 's/\.\.$//g' <<< "$var")"
        end="$(sed -n '$=' <<< "$target")"

      elif [[ $var =~ ^\.\.[1-9][0-9]*$ ]];then
        counter=1
        end="$(sed 's/^\.\.//g' <<< "$var")"

      elif [[ $var =~ ^[1-9][0-9]*$ ]]; then
        counter=$var
        end=$var

      elif [[ $var =~ ^\.\.$ ]];then
        counter=1
        end="$(sed -n '$=' <<< "$target")"

      fi

      until [ ! $counter -le $end ]; do
        entry="$(sed "$counter$getLine" <<< "$target")"

        if [[ -z "$entry" ]]; then
          query[$counter]="??"

        elif [[ -z "${query[$counter]}" ]]; then
          query[$counter]="$entry"

        fi
        counter=$((counter + 1))
      done
    done
  }

  function __rapid_get_mark {
    local entry=$1
    local markOption=$2
    local mark
    local untracked='^\?\?'

    if [[ "$markOption" == "reset" ]]; then
      if [[ "$entry" =~ ^A ]]; then
        mark="\t${fg_yellow}<${c_end} "

      elif [[ "$entry" =~ ^R ]]; then
        mark="\t${fg_yellow}~${c_end} "

      elif [[ "$entry" =~ ^[MDCU] ]]; then
        mark="\t${fg_yellow}-${c_end} "

      fi

    elif [[ "$markOption" == "drop" ]]; then
      if [[ "$entry" =~ $untracked ]]; then
        mark="\t${fg_cyan}-${c_end} "

      elif [[ "$entry" =~ ^[MADRCU\ ][MADRCU] ]]; then
        mark="\t${fg_cyan}~${c_end} "

      fi

    else
      if [[ "$entry" =~ $untracked ]]; then
        mark="\t${fg_yellow}>${c_end} "

      elif [[ "$entry" =~ ^[MADRCU\ ]R ]]; then
        mark="\t${fg_yellow}~${c_end} "

      elif [[ "$entry" =~ ^[MADRCU\ ][MDCU] ]]; then
        mark="\t${fg_yellow}+${c_end} "

      fi
    fi

    echo -e "$mark"
  }

  function __rapid_prepare {
    local out=$1
    local markOption=$2
    local git_root="$(git rev-parse --show-toplevel)"
    local format='s/^...//;s/"// g;s/ -> / / g'
    local formattedEntry
    local -a keys

    if ! __rapid_zsh; then
      # In bash, we need the array indexes that are assigned.
      keys="${!query[@]}"
    else
      # In zsh, we need an array of ordered keys of the associative array.
      keys=(${(ko)query})
    fi

    for entry in $keys; do
      if [[ "${query[$entry]}" == '??' ]]; then
        [[ "$out" == "true" ]] && output+="\t${fg_b_red}?$c_end Nothing on index $entry.\r\n"
        # Remove key.
        __rapid_zsh && unset "query[$entry]" || unset query[$entry]
      else
        formattedEntry="$(sed "$format" <<< "${query[$entry]}")"
        [[ "$out" == "true" ]] && output+="$(__rapid_get_mark "${query[$entry]}" "$markOption")$formattedEntry\r\n"
        query[$entry]="$git_root/$formattedEntry"
      fi
    done
  }

  function __rapid__track {
    local untracked='/^??/!d'

    local git_status="$(git status --porcelain)"
    local untrackedContent="$(sed "$untracked" <<< "$git_status")"
    __rapid_query "$untrackedContent" "$@"

    __rapid_prepare "true"
    printf "$output"

    git add -- "${query[@]}"
  }

  function __rapid__stage {
    local unstaged='/^[ MARC][MD]/!d'
    local -a args
    local patch='^-p|--patch$'

    if [[ "$1" =~ $patch ]]; then
      args=("${@:2}")
    else
      args=("$@")
    fi

    local git_status="$(git status --porcelain)"
    local unstagedContent="$(sed "$unstaged" <<< "$git_status")"
    __rapid_query "$unstagedContent" "$args"

    __rapid_prepare "true"
    printf "$output"

    if [[ "$1" =~ $patch ]]; then
      git add --patch -- "${query[@]}"
    else
      git add -- "${query[@]}"
    fi
  }

  function __rapid__unstage {
    local staged='/^([MARC][ MD]|D[ M])/!d'

    local git_status="$(git status --porcelain)"
    local stagedContent="$(sed -$sedE "$staged" <<< "$git_status")"
    __rapid_query "$stagedContent" "$@"

    __rapid_prepare "true" "reset"
    printf "$output"

    git reset --quiet HEAD -- "${query[@]}"
  }

  function __rapid__drop {
    local unstaged='/^[ MARC][MD]/!d'

    local git_status="$(git status --porcelain)"
    local unstagedContent="$(sed "$unstaged" <<< "$git_status")"
    __rapid_query "$unstagedContent" "$@"

    __rapid_prepare "true" "drop"
    printf "$output"

    git checkout -- "${query[@]}"
  }

  function __rapid__remove {
    local untracked='/^??/!d'

    local git_status="$(git status --porcelain)"
    local untrackedContent="$(sed "$untracked" <<< "$git_status")"
    __rapid_query "$untrackedContent" "$@"

    __rapid_prepare "true" "drop"
    printf "$output"

    rm -rf -- "${query[@]}"
  }

  function __rapid__diff {
    local git_status="$(git status --porcelain)"

    if [[ "$1" == '-c' ]]; then
      local staged='/^([MARC][ MD]|D[ M])/!d'
      local stagedContent="$(sed -$sedE "$staged" <<< "$git_status")"
      __rapid_query "$stagedContent" "${@:2}"

      __rapid_prepare "false"

      git diff --cached -- "${query[@]}"
    else
      local unstaged='/^[ MARC][MD]/!d'
      local unstagedContent="$(sed "$unstaged" <<< "$git_status")"
      __rapid_query "$unstagedContent" "$@"

      __rapid_prepare "false"

      git diff -- "${query[@]}"
    fi
  }

  function __rapid__checkout {
    local branches
    local line

    if [[ $1 == '-a' ]]; then
      branches="$(git branch -a)"
      line="$2"

    elif [[ $1 == '-r' ]]; then
      branches="$(git branch -r)"
      line="$2"

    else
      branches="$(git branch)"
      line="$1"
    fi

    if [[ "$line" =~ ^[1-9][0-9]*$ ]]; then
      local toCheckout="$(sed '/detached from/ d;' <<< "$branches" | sed -n "$line !d;s/^..//;p")"

      if [[ -z "$toCheckout" ]]; then
        echo -e "\t${fg_b_red}?$c_end Nothing on index $line."
      else
        git checkout "$toCheckout"
        return $?
      fi
    else
      echo -e "\t${fg_b_red}x$c_end Invalid input: $line."
    fi

    return 1
  }

  function __rapid__merge {
    if [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
      branch="$(git branch | sed '/detached from/ d;' | sed -n "$1 !d;s/^..//;p")"

      if [[ -z "$branch" ]]; then
        echo -e "\t${fg_b_red}?$c_end Nothing on index $1."
      else
        git merge "$branch"
        return $?
      fi
    else
      echo -e "\t${fg_b_red}x$c_end Invalid input: $1."
    fi

    return 1
  }

  function __rapid__rebase {
    local continue='^-c|--continue$'
    local abort='^-a|--abort$'

    if [[ "$1" =~ $continue ]]; then
      git rebase --continue
      return $?
    elif [[ "$1" =~ $abort ]]; then
      git rebase --abort
      return $?
    else
      local branch

      if [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
        branch="$(git branch | sed '/detached from/ d;' | sed -n "$1 !d;s/^..//;p")"

        if [[ -z "$branch" ]]; then
          echo -e "\t${fg_b_red}?$c_end Nothing on index $1."
        else
          git rebase "$branch"
          return $?
        fi
      else
        echo -e "\t${fg_b_red}x$c_end Invalid input: $1."
      fi
    fi

    return 1
  }

  function __rapid__status {
    local git_status
    git_status="$(git status --porcelain)"
    [[ $? -eq 0 ]] || return $?

    local prefixStaged="s/^M[MD ]/modified:   /;s/^A[MD ]/added:      /;s/^D[M ]/deleted:    /;s/^R[MD ]/renamed:    /; s/^C[MD ]/copied:     /"
    local prefixUnstaged="s/^[MARC ]?M/modified:   /;s/^[MARC ]?D/deleted:    /"
    local prefixUntracked="s/^\?\?/added:      /"
    local prefixUnmerged="s/^UU/modified both:     /;s/^AA/added both:        /;s/^UA/added remote:      /;s/^AU/added local:       /;s/^DD/deleted both:      /;s/^UD/deleted remote:    /;s/^DU/deleted local:     /"

    local dyeLinenumbers="s/\([1-9][0-9]*\)$/$fg_b_yellow&$c_end/"
    local staged_color="$(git config --get-color color.status.added "bold red")"
    local dyeStagedContent="s/^/$staged_color  /"
    local unstaged_color="$(git config --get-color color.status.changed "bold green")"
    local dyeUnstagedContent="s/^/$unstaged_color  /"
    local untracked_color="$(git config --get-color color.status.untracked "bold blue")"
    local dyeUntrackedContent="s/^/$untracked_color  /"
    local dyeUnmergedContent="s/^/$fg_b_magenta  /"

    local staged='/^([MARC][ MD]|D[ M])/!d'
    local stagedContent="$(sed -$sedE "$staged" <<< "$git_status")"
    local textForIndex

    if [[ -n "$stagedContent" ]]; then
      local stagedFormattedContent="$(sed = <<< "$stagedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixStaged;$dyeStagedContent;$dyeLinenumbers;p")"
      textForIndex="Index - staged content:\r\n\r\n${stagedFormattedContent}\r\n\r\n"
    fi

    local unstaged='/^[ MARC][MD]/!d'
    local unstagedContent="$(sed "$unstaged" <<< "$git_status")"
    local textForWorkTree

    if [[ -n "$unstagedContent" ]]; then
      local unstagedFormattedContent="$(sed = <<< "$unstagedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixUnstaged;$dyeUnstagedContent;$dyeLinenumbers;p")"
      textForWorkTree="Work tree - unstaged content:\r\n\r\n$unstagedFormattedContent\r\n\r\n"
    fi

    local untracked='/^??/ !d'
    local untrackedContent="$(sed "$untracked" <<< "$git_status")"
    local textForUntracked

    if [[ -n "$untrackedContent" ]]; then
      local untrackedFormattedContent="$(sed = <<< "$untrackedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixUntracked;$dyeUntrackedContent;$dyeLinenumbers;p")"
      textForUntracked="Untracked content:\r\n\r\n$untrackedFormattedContent\r\n\r\n"
    fi

    local unmerged='/^(D[DU]|A[AU]|U[ADU])/!d'
    local unmergedContent="$(sed -$sedE "$unmerged" <<< "$git_status")"
    local textForUnmerged

    if [[ -n "$unmergedContent" ]]; then
      local unmergedFormattedContent="$(sed = <<< "$unmergedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixUnmerged;$dyeUnmergedContent;$dyeLinenumbers;p")"
      textForUnmerged="Unmerged content:\r\n\r\n$unmergedFormattedContent\r\n\r\n"
    fi

    printf "${textForIndex}${textForWorkTree}${textForUntracked}${textForUnmerged}"
  }

  function __rapid__branch {
    local branches

    if [[ "$1" == '-d' ]]; then

      if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
        branch="$(git branch | sed '/detached from/ d;' | sed -n "$2 !d;s/^..//;p")"

        if [[ -z "$branch" ]]; then
          echo -e "\t${fg_b_red}?$c_end Nothing on index $2."
        else
          git branch -d "$branch"
          return $?
        fi
      else
        echo -e "\t${fg_b_red}x$c_end Invalid input: $2."
      fi

    elif [[ "$1" == '-D' ]]; then

      if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
        branch="$(git branch | sed '/detached from/ d;' | sed -n "$2 !d;s/^..//;p")"

        if [[ -z "$branch" ]]; then
          echo -e "\t${fg_b_red}?$c_end Nothing on index $2."
        else
          git branch -D "$branch"
          return $?
        fi

      else
        echo -e "\t${fg_b_red}x$c_end Invalid input: $2."
      fi

    else
      if [[ "$1" == '-a' ]]; then
        branches="$(git branch -a)"
      elif [[ "$1" == '-r' ]]; then
        branches="$(git branch -r)"
      else
        branches="$(git branch)"
      fi

      [[ $? -eq 0 ]] || return $?

      local detached="$(sed -n$sedE "/detached from/ !d;s/^\*/$fg_b_cyan>$c_end/;s/.$/&\\\\r\\\\n/;p" <<< "$branches")"
      branches="$(sed '/detached from/ d' <<< "$branches" | sed = | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "s/^/  /;s/^  \*/$fg_b_cyan>$c_end/;s/\([1-9][0-9]*\)$/$fg_b_yellow&$c_end/;p" )"
      printf "${detached}${branches}\r\n"

      return 0
    fi

    return 1
  }

  __rapid_zsh && local -A query || local -a query
  query=()
  local output
  local exit_status

  __rapid_init_colors

  local rapid_command="$command_prefix$1"
  if declare -f "$rapid_command" > /dev/null ; then
    $rapid_command "${@:2}"
  else
    __rapid_command_not_found "$1"
  fi

  exit_status=$?

  __rapid_cleanup
  return $exit_status
}
