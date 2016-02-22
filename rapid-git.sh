#!/bin/sh

function rapid {

  local function_prefix='__rapid_'
  local command_prefix="${function_prefix}_"
  local -a rapid_functions

  local filter_untracked='\?\?'
  local filter_unstaged='[ MARC][MD]'
  local filter_staged='([MARC][ MD]|D[ M])'
  local filter_unmerged='(D[DU]|A[AU]|U[ADU])'

  # Colors.
  local c_end
  local fg_black fg_red fg_green fg_yellow fg_blue fg_magenta fg_cyan fg_white
  local fg_b_black fg_b_red fg_b_green fg_b_yellow fg_b_blue fg_b_magenta fg_b_cyan fg_b_white

  function __rapid_init_colors {
    # No colors when we're part of a pipeline or output is being redirected.
    [[ -t 1 ]] || return

    c_end="$(git config --get-color "" "reset")"

    fg_yellow="$(git config --get-color "" "yellow")"
    fg_cyan="$(git config --get-color "" "cyan")"
    fg_b_red="$(git config --get-color "" "bold red")"
    fg_b_yellow="$(git config --get-color "" "bold yellow")"
    fg_b_magenta="$(git config --get-color "" "bold magenta")"
    fg_b_cyan="$(git config --get-color "" "bold cyan")"
}

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

  function __rapid_git_status {
    if __rapid_zsh; then
      # The pipefail option is not available on zsh 5.0.2, use two separate invocations. At least we can store NULLs in variables. Replace them regardless.
      local git_z_status
      git_z_status="$(git status --porcelain -z)"
      [[ $? -eq 0 ]] || return $?

      git_status="$(sed 's/\x0/\n/g' <<< "$git_z_status")"
      return $?
    fi

    # In bash we cannot store NULL characters in a variable. Go the extra mile and replace NULLs with \n.
    # http://stackoverflow.com/q/6570531
    git_status="$(set -o pipefail; git status --porcelain -z | sed 's/\x0/\n/g')"
  }

  function __rapid_filter_git_status {
    local git_status=$1
    local filter="/^$2/!d"

    printf "%s" "$(sed -r "$filter" <<< "$git_status")"
  }

  function __rapid_query {
    local target=$1

    # Process the rest of the parameters either as indexes or as git params.
    shift
    while [[ $# -gt 0 ]]; do
      local var=$1
      local index=
      local end=

      if [[ $var =~ ^[1-9][0-9]*\.\.[1-9][0-9]*$ ]]; then
        index="$(sed 's/\.\.[1-9][0-9]*$//g' <<< "$var")"
        end="$(sed 's/^[1-9][0-9]*\.\.//g' <<< "$var")"

      elif [[ $var =~ ^[1-9][0-9]*\.\.$ ]]; then
        index="$(sed 's/\.\.$//g' <<< "$var")"
        end="$(sed -n '$=' <<< "$target")"

      elif [[ $var =~ ^\.\.[1-9][0-9]*$ ]]; then
        index=1
        end="$(sed 's/^\.\.//g' <<< "$var")"

      elif [[ $var =~ ^[1-9][0-9]*$ ]]; then
        index=$var
        end=$var

      elif [[ $var =~ ^\.\.$ ]]; then
        index=1
        end="$(sed -n '$=' <<< "$target")"
      else
        git_params+=("$var")

        # Make sure the while loop below isn't entered.
        index=1
        end=$((index - 1))
      fi

      while [[ $index -le $end ]]; do
        local file_status="$(sed "$index!d" <<< "$target")"

        if [[ -z "$file_status" ]]; then
          query[$index]="??"
        elif [[ -z "${query[$index]}" ]]; then
          query[$index]="$file_status"
        fi

        index=$((index + 1))
      done

      shift
    done
  }

  function __rapid_get_mark {
    local entry=$1
    local mark_option=$2
    local mark
    local untracked='^\?\?'

    if [[ "$mark_option" == "reset" ]]; then
      if [[ "$entry" =~ ^A ]]; then
        mark="\t${fg_yellow}<${c_end} "

      elif [[ "$entry" =~ ^R ]]; then
        mark="\t${fg_yellow}~${c_end} "

      elif [[ "$entry" =~ ^[MDCU] ]]; then
        mark="\t${fg_yellow}-${c_end} "

      fi

    elif [[ "$mark_option" == "drop" ]]; then
      if [[ "$entry" =~ $untracked ]]; then
        mark="\t${fg_cyan}-${c_end} "

      elif [[ "$entry" =~ ^[MADRCU\ ][MADRCU] ]]; then
        mark="\t${fg_cyan}~${c_end} "

      fi

    elif [[ "$mark_option" != "false" ]]; then
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
    local mark_option=$1
    local git_root="$(git rev-parse --show-toplevel)"
    local -a keys

    if ! __rapid_zsh; then
      # In bash, we need the array indexes that are assigned.
      keys=("${!query[@]}")
    else
      # In zsh, we need an array of ordered keys of the associative array.
      keys=(${(ko)query})
    fi

    for key in ${keys[@]}; do
      if [[ "${query[$key]}" == '??' ]]; then
        [[ "$mark_option" != "false" ]] && output+="\t${fg_b_red}?$c_end Nothing on index $key.\n"

        # Remove key.
        __rapid_zsh && unset "query[$key]" || unset query[$key]
      else
        local file="${query[$key]}"
        # Remove git status prefix.
        file="${file:3}"
        [[ "$mark_option" != "false" ]] && output+="$(__rapid_get_mark "${query[$key]}" "$mark_option")$file\n"

        query[$key]="$git_root/$file"
      fi
    done

    printf "$output"

    if [[ "${#query[@]}" -eq 0 ]]; then
      # Nothing left likely means an error, e.g. user entered non-existing index.
      return 1
    fi
  }

  # Commands for the index.
  function __rapid_index_command {
    local git_command=$1
    local filter=$2
    local mark_option=$3

    shift 3
    local -a args
    args=($@)

    __rapid_git_status
    [[ $? -eq 0 ]] || return $?

    local lines="$(__rapid_filter_git_status "$git_status" "$filter")"
    __rapid_query "$lines" "${args[@]}"

    __rapid_prepare "$mark_option"
    if [[ $? -ne 0 ]]; then
      return 1
    fi

    local -a command
    command=()
    if ! __rapid_zsh; then
      # Split git command based on spaces.
      IFS=' ' command=($git_command)
    else
      # zsh doesn't do word splitting by default, but $=var enables it.
      command=($=git_command)
    fi

    local -a files
    if ! __rapid_zsh; then
      # In bash, we need the array values that are assigned.
      files=("${query[@]}")
    else
      # In zsh, we need an array of ordered values of the associative array.
      files=(${(vo)query})
    fi

    for git_param in "${git_params[@]}"; do
      command+=("$git_param")
    done

    command+=('--')
    for file in "${files[@]}"; do
      command+=("$file")
    done

    "${command[@]}"
  }

  function __rapid__track {
    __rapid_index_command 'git add' "$filter_untracked" 'stage' "$@"
  }

  function __rapid__stage {
    __rapid_index_command 'git add' "$filter_unstaged" 'stage' "$@"
  }

  function __rapid__unstage {
    __rapid_index_command 'git reset --quiet HEAD' "$filter_staged" 'reset' "$@"
  }

  function __rapid__drop {
    __rapid_index_command 'git checkout' "$filter_unstaged" 'drop' "$@"
  }

  function __rapid__remove {
    __rapid_index_command 'rm -rf' "$filter_untracked" 'drop' "$@"
  }

  function __rapid__diff {
    local filter="$filter_unstaged"
    local cached='^--cached|--staged$'

    if [[ "$1" =~ $cached ]]; then
      filter="$filter_staged"
    fi

    __rapid_index_command 'git diff' "$filter" 'false' "$@"
  }

  function __rapid_status_of_type {
    local header=$1
    local git_status=$2
    local filter=$3
    local color=$4

    local lines="$(__rapid_filter_git_status "$git_status" "$filter")"

    if [[ -z "$lines" ]]; then
      return
    fi

    # The other parameters are optional status replacements in the form of 'pattern' 'replacement'.
    local prefixes
    shift 4
    while [[ $# -gt 0 ]]; do
      prefixes+="s/\t$1\t/\t$2\t/;"
      shift 2
    done

    local index_color=$fg_b_yellow

    # No colors when we're part of a pipeline or output is being redirected.
    local colorize
    if [[ -t 1 ]]; then
      colorize="s/^(.*)\t(.*)\t(.*)/$index_color\1$c_end\t$color\2$c_end\t$color\3$c_end/"
    fi

    local order_fields='s/^(.*)\t(.*)\t(.*)/  \2 \1 \3/'

    local formatted="$(
      sed -r '
        # Put index between lines: <status> <file> -> <index>\n<status> <file>
        {=}
        ' <<< "$lines" | \
      sed --silent -r -e '
        # <index>\n<status> <file> -> <index>\t<status> <file>
        {N;s/\n/\t/}
      ' -e :a -e "
        # Right-pad indexes shorter than three characters to three characters.
        {s/^[ 0-9]{1,2}\t.*/ &/;ta}
      " -e "
        # <index>\t<status> <file> -> (<index>)\t<status>\t<file>
        {s/^(( *)([1-9][0-9]*))\t(..) (.*)/\2(\3)\t\4\t\5/}

        # Replace status with text, colorize fields, reorder fields.
        {$prefixes;$colorize;$order_fields;p}"
      )"

    printf "%s:\n\n%s\n\n" "$header" "$formatted"
  }

  function __rapid__status {
    __rapid_git_status
    [[ $? -eq 0 ]] || return $?

    __rapid_status_of_type 'Index - staged files' \
      "$git_status" \
      "$filter_staged" \
      "$(git config --get-color color.status.added "bold green")" \
      'M[MD ]'    'modified:        ' \
      'A[MD ]'    'new file:        ' \
      'D[M ]'     'deleted:         ' \
      'R[MD ]'    'renamed:         ' \
      'C[MD ]'    'copied:          '

    __rapid_status_of_type 'Work tree - unstaged files' \
      "$git_status" \
      "$filter_unstaged" \
      "$(git config --get-color color.status.changed "bold green")" \
      '[MARC ]?M' 'modified:        ' \
      '[MARC ]?D' 'deleted:         '

    __rapid_status_of_type 'Untracked files' \
      "$git_status" \
      "$filter_untracked" \
      "$(git config --get-color color.status.untracked "bold blue")" \
      '\?\?'      'untracked file:  '

    __rapid_status_of_type 'Unmerged files' \
      "$git_status" \
      "$filter_unmerged" \
      "$fg_b_magenta" \
      'UU'        'both modified:   ' \
      'AA'        'both added:      ' \
      'UA'        'added by them:   ' \
      'AU'        'added by us:     ' \
      'DD'        'both deleted:    ' \
      'UD'        'deleted by them: ' \
      'DU'        'deleted by us:   '
  }

  # Commands for branches.
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

      branches="$(
        sed '/detached from/ d' <<< "$branches" | \
        sed -r {=} | \
        sed --silent -r -e '
          {N;s/\n/\t/}
        ' -e :a -e "
          {s/^[ 0-9]{1,2}\t.*/ &/;ta}
        " -e "
        # <index><marker (*)><branch-name> -> <marker>\t<index>\t<branch-name>
        {s/^([ 0-9]{3})\t([ *] )(.*)/\2\1\t\3/}
        # Replace * with >
        {s/^(\*)/>/}
        # Expands 1 to (1), 2 to (2), ...
        {s/([0-9]{1,3})(\t.*)/(\1)\2/}
        # Colorizes the current branch
        {s/^(>.+)(\([0-9]{1,3}\))(.*)/$fg_b_cyan\1$c_end$fg_b_yellow\2$c_end$fg_b_cyan\3$c_end/}
        # Colorizes the current branch
        {s/^([^>]+)(\([0-9]{1,3}\))(.*)/\1$fg_yellow\2$c_end$fg_cyan\3$c_end/}
        p"
      )"

      printf "${branches}\r\n"

      return 0
    fi

    return 1
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
      local toCheckout="$(
        sed -n "$line !d
          s/^..//
        p" <<< "$branches"
      )"

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

  __rapid_zsh && local -A query || local -a query
  query=()
  local -a git_params
  git_params=()
  local git_status
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
