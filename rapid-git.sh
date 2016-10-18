#!/bin/sh

function rapid {

  local function_prefix='__rapid_'
  local command_prefix="${function_prefix}_"
  local -a rapid_functions

  local falsey='^false|off|0$'

  local -A filter
  filter[untracked]='\?\?'
  filter[unstaged]='[ MARC][MD]'
  filter[staged]='([MARC][ MD]|D[ M])'
  filter[unmerged]='(D[DU]|A[AU]|U[ADU])'

  local -A colors
  local -A git_color_cache

  function __rapid_colorize {
    # No colors if requested.
    [[ $RAPID_GIT_COLORS =~ $falsey ]] && return 1

    # Colors when we're:
    #   - not part of a pipeline, or
    #   - output is not being redirected.
    [[ -t 1 ]] && return 0

    # No colors.
    return 1
  }

  function __rapid_color_value {
    # Color selection:
    #   1. Use explicitly configured color from the RAPID_GIT_COLORS
    #      associative array.
    #   2. Use corresponding git config value, if available.
    #   3. Otherwise, use git-supplied color code.
    #
    # We could use git config to configure custom colors, but that would force
    # us to create a git process. On Windows, this is as slow as a snail bound
    # to a turtle. Both moving in opposite directions.
    #
    # To alleviate the problem a bit, we build a cache of git color values.
    #
    local key=$1
    local git_config=$2
    local git_default=$3
    local value

    value="${RAPID_GIT_COLORS[$key]}"
    if [[ -z "$value" ]]; then
      cache_key="$git_config-$git_default"

      value="${git_color_cache[$cache_key]:-$(git config --get-color "$git_config" "$git_default")}"
      git_color_cache[$cache_key]="$value"
    fi

    colors[$key]="$value"
  }

  function __rapid_init_colors {
    __rapid_colorize || return

    __rapid_color_value 'reset'                ''                       'reset'
    __rapid_color_value 'branch'               'color.branch.local'     'cyan'
    __rapid_color_value 'branch_index'         ''                       'yellow'
    __rapid_color_value 'branch_current'       'color.branch.current'   'bold cyan'
    __rapid_color_value 'branch_current_index' ''                       'bold yellow'
    __rapid_color_value 'status_index'         ''                       'bold yellow'
    __rapid_color_value 'status_staged'        'color.status.added'     'bold red'
    __rapid_color_value 'status_unstaged'      'color.status.changed'   'bold green'
    __rapid_color_value 'status_untracked'     'color.status.untracked' 'bold blue'
    __rapid_color_value 'status_unmerged'      'color.status.changed'   'bold magenta'
    __rapid_color_value 'mark_stage'           ''                       'yellow'
    __rapid_color_value 'mark_reset'           ''                       'yellow'
    __rapid_color_value 'mark_drop'            ''                       'cyan'
    __rapid_color_value 'mark_error'           ''                       'bold red'
  }

  function __rapid_zsh {
    [[ -n "$ZSH_VERSION" ]]
  }

  function __rapid_functions {
    local function_prefix=$1

    rapid_functions=()
    if ! __rapid_zsh; then
      # Bash uses declare to return all functions.
      while read -r _declare _f fun; do
        [[ "$fun" =~ ^$function_prefix ]] && rapid_functions+=("$fun")
      done <<< "$(declare -F)"
    else
      # zsh has a function associative array.
      local -a all_functions
      all_functions=(${(ok)functions})
      rapid_functions=(${${(M)all_functions:#$function_prefix*}})
    fi
  }

  function __rapid_cleanup {
    __rapid_functions "$function_prefix"

    for fun in "${rapid_functions[@]}"; do
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
    local include_filter="^$2"

    while IFS= read -r line; do
      [[ "$line" =~ $include_filter ]] && lines+="$line"$'\n'
    done <<< "$git_status"

    # Delete last newline.
    lines="${lines%?}"
  }

  function __rapid_query_lines {
    local lines="$1"
    local index="$2"
    local end="$3"

    while [[ $index -le $end ]]; do
      local target="$(sed "$index!d" <<< "$lines")"

      if [[ -z "$target" ]]; then
        query[$index]="??"
      elif [[ -z "${query[$index]}" ]]; then
        query[$index]="$target"
      fi

      index=$((index + 1))
    done
  }

  function __rapid_query_index_and_git_params {
    local lines="$1"
    local got_index="false"

    # Process the rest of the parameters either as indexes or as git params.
    shift
    while [[ $# -gt 0 ]]; do

      if [[ "$got_index" == "false" && $1 =~ ^[1-9][0-9]*$ ]]; then
        __rapid_query_lines "$lines" "$1" "$1"
        got_index="true"
      else
        git_params+=("$1")
      fi

      shift
    done
  }

  function __rapid_query_indexes_and_git_params {
    local lines="$1"

    # Process the rest of the parameters either as indexes or as git params.
    shift
    while [[ $# -gt 0 ]]; do

      if [[ $1 =~ ^[1-9][0-9]*$ ]]; then
        __rapid_query_lines "$lines" "$1" "$1"
      else
        git_params+=("$1")
      fi

      shift
    done
  }

  function __rapid_query_ranges_and_git_params {
    local lines="$1"

    # Process the rest of the parameters either as indexes or as git params.
    shift
    while [[ $# -gt 0 ]]; do
      local var=$1
      local index=
      local end=

      if [[ $var =~ ^[1-9][0-9]*[.][.][1-9][0-9]*$ ]]; then
        index="$(sed 's/\.\.[1-9][0-9]*$//g' <<< "$var")"
        end="$(sed 's/^[1-9][0-9]*\.\.//g' <<< "$var")"

      elif [[ $var =~ ^[1-9][0-9]*[.][.]$ ]]; then
        index="$(sed 's/\.\.$//g' <<< "$var")"
        end="$(sed -n '$=' <<< "$lines")"

      elif [[ $var =~ ^[.][.][1-9][0-9]*$ ]]; then
        index=1
        end="$(sed 's/^\.\.//g' <<< "$var")"

      elif [[ $var =~ ^[1-9][0-9]*$ ]]; then
          index=$var
          end=$var

      elif [[ $var =~ ^[.][.]$ ]]; then
        index=1
        end="$(sed -n '$=' <<< "$lines")"

      else
        git_params+=("$var")

        # Make sure the while loop below isn't entered.
        index=1
        end=$((index - 1))
      fi

      __rapid_query_lines "$lines" "$index" "$end"
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
        mark="\t${colors[mark_reset]}<${colors[reset]} "

      elif [[ "$entry" =~ ^R ]]; then
        mark="\t${colors[mark_reset]}~${colors[reset]} "

      elif [[ "$entry" =~ ^[MDCU] ]]; then
        mark="\t${colors[mark_reset]}-${colors[reset]} "

      fi

    elif [[ "$mark_option" == "drop" ]]; then
      if [[ "$entry" =~ $untracked ]]; then
        mark="\t${colors[mark_drop]}-${colors[reset]} "

      elif [[ "$entry" =~ ^[MADRCU\ ][MADRCU] ]]; then
        mark="\t${colors[mark_drop]}~${colors[reset]} "

      fi

    elif [[ "$mark_option" != "false" ]]; then
      if [[ "$entry" =~ $untracked ]]; then
        mark="\t${colors[mark_stage]}>${colors[reset]} "

      elif [[ "$entry" =~ ^[MADRCU\ ]R ]]; then
        mark="\t${colors[mark_stage]}~${colors[reset]} "

      elif [[ "$entry" =~ ^[MADRCU\ ][MDCU] ]]; then
        mark="\t${colors[mark_stage]}+${colors[reset]} "

      fi
    fi

    echo -e "$mark"
  }

  function __rapid_prepare {
    local mark_option="$1"
    local is_branch_command="$2"
    local git_root="$(git rev-parse --show-toplevel)"
    local prefix_count
    local new_prefix

    if [[ "$is_branch_command" != "true" ]]; then
      prefix_count=3
      new_prefix="$git_root/"
    else
      prefix_count=2
    fi

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
        [[ "$mark_option" != "false" ]] && output+="\t${colors[mark_error]}?${colors[reset]} Nothing on index $key.\n"

        # Remove key.
        __rapid_zsh && unset "query[$key]" || unset query[$key]
      else
        local target="${query[$key]}"
        # Remove git status/branch prefix.
        target="${target:$prefix_count}"
        [[ "$mark_option" != "false" ]] && output+="$(__rapid_get_mark "${query[$key]}" "$mark_option")$target\n"

        query[$key]="$new_prefix$target"
      fi
    done

    printf "$output"

    if [[ "${#query[@]}" -eq 0 ]]; then
      # Nothing left likely means an error, e.g. user entered non-existing index.
      return 1
    fi
  }

  # Color configuration commands.
  function __rapid__colors {
    local -a keys

    if ! __rapid_zsh; then
      # In bash, we need the array indexes that are assigned.
      keys=("${!colors[@]}")
    else
      # In zsh, we need an array of ordered keys of the associative array.
      keys=(${(ko)colors})
    fi

    for key in ${keys[@]}; do
      echo "$key -> ${colors[$key]}xxx${colors[reset]}"
    done
  }

  # Commands for the index.
  function __rapid_index_committing_command {
    local git_command=$1
    local filter=$2
    local mark_option=$3

    shift 3
    local -a args
    args=($@)

    __rapid_git_status
    [[ $? -eq 0 ]] || return $?

    local lines
    __rapid_filter_git_status "$git_status" "$filter"
    __rapid_query_ranges_and_git_params "$lines" "${args[@]}"

    __rapid_prepare "$mark_option"
    if [[ $? -ne 0 ]]; then
      return 1
    fi

    __rapid_construct_command "$git_command" "committing"
  }

  function __rapid_construct_command {
    local git_command="$1"
    local variant="$2"

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

    [[ "$variant" == "committing" ]] && command+=('--')
    for file in "${files[@]}"; do
      command+=("$file")
    done

    "${command[@]}"
  }

  function __rapid__track {
    __rapid_index_committing_command 'git add' "${filter[untracked]}" 'stage' "$@"
  }

  function __rapid__stage {
    __rapid_index_committing_command 'git add' "${filter[unstaged]}" 'stage' "$@"
  }

  function __rapid__unstage {
    __rapid_index_committing_command 'git reset --quiet' "${filter[staged]}" 'reset' "$@"
  }

  function __rapid__drop {
    __rapid_index_committing_command 'git checkout' "${filter[unstaged]}" 'drop' "$@"
  }

  function __rapid__remove {
    __rapid_index_committing_command 'rm -rf' "${filter[untracked]}" 'drop' "$@"
  }

  function __rapid__diff {
    local filter="${filter[unstaged]}"
    local cached='^--cached|--staged$'

    if [[ "$1" =~ $cached ]]; then
      filter="${filter[staged]}"
    fi

    __rapid_index_committing_command 'git diff' "$filter" 'false' "$@"
  }

  function __rapid_status_of_type {
    local header=$1
    local git_status=$2
    local filter=$3
    local color=$4

    local lines
    __rapid_filter_git_status "$git_status" "$filter"

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

    local colorize
    if __rapid_colorize; then
      colorize="s/^(.*)\t(.*)\t(.*)/${colors[status_index]}\1${colors[reset]}\t$color\2${colors[reset]}\t$color\3${colors[reset]}/"
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
      "${filter[staged]}" \
      "${colors[status_staged]}" \
      'M[MD ]'    'modified:        ' \
      'A[MD ]'    'new file:        ' \
      'D[M ]'     'deleted:         ' \
      'R[MD ]'    'renamed:         ' \
      'C[MD ]'    'copied:          '

    __rapid_status_of_type 'Work tree - unstaged files' \
      "$git_status" \
      "${filter[unstaged]}" \
      "${colors[status_unstaged]}" \
      '[MARC ]?M' 'modified:        ' \
      '[MARC ]?D' 'deleted:         '

    __rapid_status_of_type 'Untracked files' \
      "$git_status" \
      "${filter[untracked]}" \
      "${colors[status_untracked]}" \
      '\?\?'      'untracked file:  '

    __rapid_status_of_type 'Unmerged files' \
      "$git_status" \
      "${filter[unmerged]}" \
      "${colors[status_unmerged]}" \
      'UU'        'both modified:   ' \
      'AA'        'both added:      ' \
      'UA'        'added by them:   ' \
      'AU'        'added by us:     ' \
      'DD'        'both deleted:    ' \
      'UD'        'deleted by them: ' \
      'DU'        'deleted by us:   '
  }

  function __rapid_index_branching_command {
    local git_command="$1"
    local variant=$2

    shift 2
    local -a args
    args=($@)

    if [[ "$variant" == "index" ]]; then
      __rapid_query_index_and_git_params "$(git branch)" "${args[@]}"

    elif [[ "$variant" == "indexes" ]]; then
      __rapid_query_indexes_and_git_params "$(git branch)" "${args[@]}"

    elif [[ "$variant" == "ranges"  ]]; then
      __rapid_query_ranges_and_git_params "$(git branch)" "${args[@]}"

    else
      return 1
    fi

    __rapid_prepare "false" "true"
    if [[ $? -ne 0 ]]; then
      return 1
    fi

    __rapid_construct_command "$git_command" "branching"
  }

  # Commands for branches.
  function __rapid__branch {
    local branches

    if [[ "$1" == '-d' ]] || [[ "$1" == '-D' ]]; then
      local delete_param="$1"
      shift

      __rapid_index_branching_command "git branch $delete_param" 'ranges' "$@"
      return $?

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
        {s/^(>.+)(\([0-9]{1,3}\))(.*)/${colors[branch_current]}\1${colors[reset]}${colors[branch_current_index]}\2${colors[reset]}${colors[branch_current]}\3${colors[reset]}/}
        # Colorizes other branches
        {s/^([^>]+)(\([0-9]{1,3}\))(.*)/\1${colors[branch_index]}\2${colors[reset]}${colors[branch]}\3${colors[reset]}/}
        p"
      )"

      printf "${branches}\n"

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
        echo -e "\t${colors[mark_error]}?${colors[reset]} Nothing on index $line."
      else
        git checkout "$toCheckout"
        return $?
      fi
    else
      echo -e "\t${colors[mark_error]}x${colors[reset]} Invalid input: $line."
    fi

    return 1
  }

  function __rapid__merge {
    if [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
      branch="$(git branch | sed '/detached from/ d;' | sed -n "$1 !d;s/^..//;p")"

      if [[ -z "$branch" ]]; then
        echo -e "\t${colors[mark_error]}?${colors[reset]} Nothing on index $1."
      else
        git merge "$branch"
        return $?
      fi
    else
      echo -e "\t${colors[mark_error]}x${colors[reset]} Invalid input: $1."
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
          echo -e "\t${colors[mark_error]}?${colors[reset]} Nothing on index $1."
        else
          git rebase "$branch"
          return $?
        fi
      else
        echo -e "\t${colors[mark_error]}x${colors[reset]} Invalid input: $1."
      fi
    fi

    return 1
  }

  function __rapid__push {
    local remote="origin"

    __rapid_index_branching_command "git push $remote" 'index' "$@"
    return $?
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
