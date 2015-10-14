#!/bin/sh

# temporary hack until an installer function is written
if [ $(uname -s) = 'Darwin' ]; then
	sedE='E'
else
	sedE='r'
fi

function rapid {

	local query=()
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
			if [[ "$entry" =~ ^\?\? ]]; then
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
		local path=$(git rev-parse --show-toplevel)
		local format='s/^...//;s/"// g;s/ -> / / g'
		local formattedEntry
		local output

		for entry in "${!query[@]}"; do
			if [[ "${query[$entry]}" == "??" ]]; then
				[[ "$out" == "true" ]] && output+="\t${fg_b_red}?$c_end Nothing on index $entry.\r\n"
				unset query[$entry]

			else
				formattedEntry=$(sed "$format" <<< "${query[$entry]}")
				[[ "$out" == "true" ]] && output+="$(__rapid__get_mark "${query[$entry]}" "$markOption")$formattedEntry\r\n"
				query[$entry]="$path/$formattedEntry"

			fi
		done

		printf "$output"
	}

  function __rapid__track {
		local untracked='/^??/ !d'

		local status=$(git status --porcelain)
		local untrackedContent=$(sed "$untracked" <<< "$status")
		__rapid__query "$untrackedContent" "$@"

		__rapid__prepare "true"

		git add "${query[@]}"
		printf "$output"
  }

	function __rapid__stage {
		local unstaged='/^[MADRCU ][MADRCU]/!d'
		local args

		if [[ "$1" =~ ^-p|--patch$ ]]; then
			args="${@:2}"
		else
			args="$@"
		fi

		local status=$(git status --porcelain)
		local unstagedContent=$(sed "$unstaged" <<< "$status")
		__rapid__query "$unstagedContent" "$args"

		__rapid__prepare "true"

		if [[ "$1" =~ ^-p|--patch$ ]]; then
			git add --patch "${query[@]}"
		else
			git add "${query[@]}"
		fi

		printf "$output"
	}

  function __rapid__unstage {
  	local staged='/^[MADRCU][MADRCU ]/!d'

		local status=$(git status --porcelain)
		local stagedContent=$(sed "$staged" <<< "$status")
		__rapid__query "$stagedContent" "$@"

		__rapid__prepare "true" "reset"

		git reset --quiet HEAD "${query[@]}"
		printf "$output"
  }

	function __rapid__drop {
		local unstaged='/^[MADRCU ][MADRCU]/!d'

		local status=$(git status --porcelain)
		local unstagedContent=$(sed "$unstaged" <<< "$status")
		__rapid__query "$unstagedContent" "$@"

		__rapid__prepare "true" "drop"

		git checkout -- "${query[@]}"
		printf "$output"
	}

	function __rapid__remove {
		local untracked='/^??/!d'

		local status=$(git status --porcelain)
		local untrackedContent=$(sed "$untracked" <<< "$status")
		__rapid__query "$untrackedContent" "$@"

		__rapid__prepare "true" "drop"

		rm -rf "${query[@]}"
		printf "$output"
	}

	function __rapid__diff {
		local status=$(git status --porcelain)

		if [ $1 == '-c' ]; then
			local staged='/^[MADRCU][MADRCU ]/!d'
			local stagedContent=$(sed "$staged" <<< "$status")
			__rapid__query "$stagedContent" "${@:2}"

			__rapid__prepare "false" "reset"

			git diff --cached "${query[@]}"

		else
			local unstaged='/^[MADRCU ][MADRCU]/!d'
			local unstagedContent=$(sed "$unstaged" <<< "$status")
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
		if [[ "$1" =~ ^-c|--continue$ ]]; then
			git rebase --continue

		elif [[ "$1" =~ ^-a|--abort$ ]]; then
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

			branches=$(sed = <<< "$branches" | sed '{N;s/\n/ /}' | sed -e 's/^\([1-9][0-9]*\)  *\(.*\)/\2 \(\1\)/' | sed -n$sedE "s/^/  /;s/^  \*/$fg_b_cyan>$c_end/;s/\([1-9][0-9]*\)$/$fg_b_yellow&$c_end/;p" )
			printf "$branches\r\n"

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
}
