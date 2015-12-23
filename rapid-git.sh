#!/bin/sh

# temporary hack until an installer function is written
if [ $(uname -s) = 'Darwin' ]; then
  sedE='E'
else
  sedE='r'
fi

function rapid {
  [[ -n "$ZSH_VERSION" ]] && local -A query || local -a query
  query=()
  local output

  function __rapid__query {
    local target=$1
    local getLine=' !d'
    local counter
    local end
    local entry

    for var in ${@:2}; do
      count=""
      end=""

      if [[ $var =~ ^[1-9][0-9]*\.\.[1-9][0-9]*$ ]]; then
        counter=$(sed 's/\.\.[1-9][0-9]*$//g' <<< "$var")
        end=$(sed 's/^[1-9][0-9]*\.\.//g' <<< "$var")

      elif [[ $var =~ ^[1-9][0-9]*\.\.$ ]];then
        counter=$(sed 's/\.\.$//g' <<< "$var")
        end=$(sed -n '$=' <<< "$target")

      elif [[ $var =~ ^\.\.[1-9][0-9]*$ ]];then
        counter=1
        end=$(sed 's/^\.\.//g' <<< "$var")

      elif [[ $var =~ ^[1-9][0-9]*$ ]]; then
        counter=$var
        end=$var

      elif [[ $var =~ ^\.\.$ ]];then
        counter=1
        end=$(sed -n '$=' <<< "$target")

      fi

      until [ ! $counter -le $end ]; do
        entry=$(sed "$counter$getLine" <<< "$target")

        if [[ -z "$entry" ]]; then
          query[$counter]="??"

        elif [[ -z "${query[$counter]}" ]]; then
          query[$counter]="$entry"

        fi
        counter=$(expr $counter + 1)
      done
    done
  }

  function __rapid__get_mark {
    local entry=$1
    local markOption=$2
    local mark

    if [[ "$markOption" == "reset" ]]; then
      if [[ "$entry" =~ ^A ]]; then
        mark="\t${fg_yellow}<${c_end} "

      elif [[ "$entry" =~ ^R ]]; then
        mark="\t${fg_yellow}~${c_end} "

      elif [[ "$entry" =~ ^[MDCU] ]]; then
        mark="\t${fg_yellow}-${c_end} "

      fi

    elif [[ "$markOption" == "drop" ]]; then
      if [[ "$entry" =~ ^\?\? ]]; then
        mark="\t${fg_cyan}-${c_end} "

      elif [[ "$entry" =~ ^[MADRCU\ ][MADRCU] ]]; then
        mark="\t${fg_cyan}~${c_end} "

      fi

    else
      local untracked='^\?\?'
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

  function __rapid__prepare {
    local out=$1
    local markOption=$2
    local git_root=$(git rev-parse --show-toplevel)
    local format='s/^...//;s/"// g;s/ -> / / g'
    local formattedEntry
    local -a keys

    if [[ -z "$ZSH_VERSION" ]]; then
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
        [[ -n "$ZSH_VERSION" ]] && unset "query[$entry]" || unset query[$entry]
      else
        formattedEntry=$(sed "$format" <<< "${query[$entry]}")
        [[ "$out" == "true" ]] && output+="$(__rapid__get_mark "${query[$entry]}" "$markOption")$formattedEntry\r\n"
        query[$entry]="$git_root/$formattedEntry"
      fi
    done
  }

  function __rapid__track {
    local untracked='/^??/ !d'

    local git_status=$(git status --porcelain)
    local untrackedContent=$(sed "$untracked" <<< "$git_status")
    __rapid__query "$untrackedContent" "$@"

    __rapid__prepare "true"

    git add "${query[@]}"
    printf "$output"
  }

  function __rapid__stage {
    local unstaged='/^[ MARC][MD]/!d'
    local args
    local patch='^-p|--patch$'

    if [[ "$1" =~ $patch ]]; then
      args="${@:2}"
    else
      args="$@"
    fi

    local git_status=$(git status --porcelain)
    local unstagedContent=$(sed "$unstaged" <<< "$git_status")
    __rapid__query "$unstagedContent" "$args"

    __rapid__prepare "true"

    if [[ "$1" =~ $patch ]]; then
      git add --patch "${query[@]}"
    else
      git add "${query[@]}"
    fi

    printf "$output"
  }

  function __rapid__unstage {
    local staged='/^([MARC][ MD]|D[ M])/!d'

    local git_status=$(git status --porcelain)
    local stagedContent=$(sed -e "$staged" <<< "$git_status")
    __rapid__query "$stagedContent" "$@"

    __rapid__prepare "true" "reset"

    git reset --quiet HEAD "${query[@]}"
    printf "$output"
  }

  function __rapid__drop {
    local unstaged='/^[ MARC][MD]/!d'

    local git_status=$(git status --porcelain)
    local unstagedContent=$(sed "$unstaged" <<< "$git_status")
    __rapid__query "$unstagedContent" "$@"

    __rapid__prepare "true" "drop"

    git checkout -- "${query[@]}"
    printf "$output"
  }

  function __rapid__remove {
    local untracked='/^??/!d'

    local git_status=$(git status --porcelain)
    local untrackedContent=$(sed "$untracked" <<< "$git_status")
    __rapid__query "$untrackedContent" "$@"

    __rapid__prepare "true" "drop"

    rm -rf "${query[@]}"
    printf "$output"
  }

  function __rapid__diff {
    local git_status=$(git status --porcelain)

    if [ $1 == '-c' ]; then
      local staged='/^([MARC][ MD]|D[ M])/!d'
      local stagedContent=$(sed -e "$staged" <<< "$git_status")
      __rapid__query "$stagedContent" "${@:2}"

      __rapid__prepare "false" "reset"

      git diff --cached "${query[@]}"

    else
      local unstaged='/^[ MARC][MD]/!d'
      local unstagedContent=$(sed "$unstaged" <<< "$git_status")
      __rapid__query "$unstagedContent" "$@"

      __rapid__prepare "false"

      git diff "${query[@]}"

    fi
  }

  function __rapid__checkout {
    local branches
    local line

    if [[ $1 == '-a' ]]; then
      branches=$(git branch -a)
      line="$2"

    elif [[ $1 == '-r' ]]; then
      branches=$(git branch -r)
      line="$2"

    else
      branches=$(git branch)
      line="$1"
    fi

    if [[ "$line" =~ ^[1-9][0-9]*$ ]]; then
      local toCheckout=$(sed '/detached from/ d;' <<< "$branches" | sed -n "$line !d;s/^..//;p")

      if [[ -z "$toCheckout" ]]; then
        echo -e "\t${fg_b_red}?$c_end Nothing on index $line."
      else
        git checkout "$toCheckout"
      fi

    else
      echo -e "\t${fg_b_red}x$c_end Invalid input: $line."

    fi
  }

  function __rapid__merge {
    if [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
      branch=$(git branch | sed '/detached from/ d;' | sed -n "$1 !d;s/^..//;p")

      if [[ -z "$branch" ]]; then
        echo -e "\t${fg_b_red}?$c_end Nothing on index $1."
      else
        git merge "$branch"
      fi

    else
      echo -e "\t${fg_b_red}x$c_end Invalid input: $1."
    fi
  }

  function __rapid__rebase {
    local continue='^-c|--continue$'
    local abort='^-a|--abort$'

    if [[ "$1" =~ $continue ]]; then
      git rebase --continue

    elif [[ "$1" =~ $abort ]]; then
      git rebase --abort

    else
      local branch

      if [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
        branch=$(git branch | sed '/detached from/ d;' | sed -n "$1 !d;s/^..//;p")

        if [[ -z "$branch" ]]; then
          echo -e "\t${fg_b_red}?$c_end Nothing on index $1."
        else
          git rebase "$branch"
        fi

      else
        echo -e "\t${fg_b_red}x$c_end Invalid input: $1."
      fi
    fi
  }

  function __rapid__status {
    local git_status=$(git status --porcelain)

    local prefixStaged="s/^M[MD ]/modified:   /;s/^A[MD ]/added:      /;s/^D[M ]/deleted:    /;s/^R[MD ]/renamed:    /; s/^C[MD ]/copied:     /"
    local prefixUnstaged="s/^[MARC ]?M/modified:   /;s/^[MARC ]?D/deleted:    /"
    local prefixUntracked="s/^\?\?/added:      /"
    local prefixUnmerged="s/^UU/modified both:     /;s/^AA/added both:        /;s/^UA/added remote:      /;s/^AU/added local:       /;s/^DD/deleted both:      /;s/^UD/deleted remote:    /;s/^DU/deleted local:     /"

    local dyeLinenumbers="s/\([1-9][0-9]*\)$/$fg_b_yellow&$c_end/"
    local dyeStagedContent="s/^/$fg_b_red  /"
    local dyeUnstagedContent="s/^/$fg_b_green  /"
    local dyeUntrackedContent="s/^/$fg_b_blue  /"
    local dyeUnmergedContent="s/^/$fg_b_magenta  /"

    local staged='/^([MARC][ MD]|D[ M])/!d'
    local stagedContent=$(sed -e "$staged" <<< "$git_status")
    local textForIndex

    if [[ -n "$stagedContent" ]]; then
      local stagedFormattedContent=$(sed = <<< "$stagedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixStaged;$dyeStagedContent;$dyeLinenumbers;p")
      textForIndex="Index - staged content:\r\n\r\n${stagedFormattedContent}\r\n\r\n"
    fi

    local unstaged='/^[ MARC][MD]/!d'
    local unstagedContent=$(sed "$unstaged" <<< "$git_status")
    local textForWorkTree

    if [[ -n "$unstagedContent" ]]; then
      local unstagedFormattedContent=$(sed = <<< "$unstagedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixUnstaged;$dyeUnstagedContent;$dyeLinenumbers;p")
      textForWorkTree="Work tree - unstaged content:\r\n\r\n$unstagedFormattedContent\r\n\r\n"
    fi

    local untracked='/^??/ !d'
    local untrackedContent=$(sed "$untracked" <<< "$git_status")
    local textForUntracked

    if [[ -n "$untrackedContent" ]]; then
      local untrackedFormattedContent=$(sed = <<< "$untrackedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixUntracked;$dyeUntrackedContent;$dyeLinenumbers;p")
      textForUntracked="Untracked content:\r\n\r\n$untrackedFormattedContent\r\n\r\n"
    fi

    local unmerged='/^(D[DU]|A[AU]|U[ADU]|)/!d'
    local unmergedContent=$(sed -e "$unmerged" <<< "$git_status")
    local textForUnmerged

    if [[ -n "$unmergedContent" ]]; then
      local unmergedFormattedContent=$(sed = <<< "$unmergedContent" | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "$prefixUnmerged;$dyeUnmergedContent;$dyeLinenumbers;p")
      textForUnmerged="Unmerged content:\r\n\r\n$unmergedFormattedContent\r\n\r\n"
    fi

    printf "${textForIndex}${textForWorkTree}${textForUntracked}${textForUnmerged}"
  }

  function __rapid__branch {
    local branches

    if [ "$1" == '-d' ]; then

      if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
        branch=$(git branch | sed '/detached from/ d;' | sed -n "$2 !d;s/^..//;p")

        if [[ -z "$branch" ]]; then
          echo -e "\t${fg_b_red}?$c_end Nothing on index $2."
        else
          git branch -d "$branch"
        fi

      else
        echo -e "\t${fg_b_red}x$c_end Invalid input: $2."
      fi

    elif [ "$1" == '-D' ]; then

      if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
        branch=$(git branch | sed '/detached from/ d;' | sed -n "$2 !d;s/^..//;p")

        if [[ -z "$branch" ]]; then
          echo -e "\t${fg_b_red}?$c_end Nothing on index $2."
        else
          git branch -D "$branch"
        fi

      else
        echo -e "\t${fg_b_red}x$c_end Invalid input: $2."
      fi

    else
      if [[ "$1" == '-a' ]]; then
        branches=$(git branch -a)
      elif [[ "$1" == '-r' ]]; then
        branches=$(git branch -r)
      else
        branches=$(git branch)
      fi

      local detached=$(sed -n$sedE "/detached from/ !d;s/^\*/$fg_b_cyan>$c_end/;s/.$/&\\\\r\\\\n/;p" <<< "$branches")
      branches=$(sed '/detached from/ d' <<< "$branches" | sed = | sed '{N;s/\n/ /;}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "s/^/  /;s/^  \*/$fg_b_cyan>$c_end/;s/\([1-9][0-9]*\)$/$fg_b_yellow&$c_end/;p" )
      printf "${detached}${branches}\r\n"

    fi
  }

  if [[ $1 == 'track' ]]; then
    __rapid__track ${@:2}

  elif [[ $1 == 'stage' ]]; then
    __rapid__stage ${@:2}

  elif [[ $1 == 'unstage' ]]; then
    __rapid__unstage ${@:2}

  elif [[ $1 == 'drop' ]]; then
    __rapid__drop ${@:2}

  elif [[ $1 == 'remove' ]]; then
    __rapid__remove ${@:2}

  elif [[ $1 == 'diff' ]]; then
    __rapid__diff ${@:2}

  elif [[ $1 == 'checkout' ]]; then
    __rapid__checkout ${@:2}

  elif [[ $1 == 'merge' ]]; then
    __rapid__merge ${@:2}

  elif [[ $1 == 'rebase' ]]; then
    __rapid__rebase ${@:2}

  elif [[ $1 == 'branch' ]]; then
    __rapid__branch ${@:2}

  elif [[ $1 == 'status' ]]; then
    __rapid__status

  fi

  unset -f __rapid__query
  unset -f __rapid__get_mark
  unset -f __rapid__prepare
  unset -f __rapid__track
  unset -f __rapid__stage
  unset -f __rapid__unstage
  unset -f __rapid__drop
  unset -f __rapid__remove
  unset -f __rapid__diff
  unset -f __rapid__checkout
  unset -f __rapid__merge
  unset -f __rapid__rebase
  unset -f __rapid__branch
  unset -f __rapid__status
}
