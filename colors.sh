#!/bin/sh

function xterm_color {

  c_bold=$(tput bold)
  c_end=$(tput sgr0)

  fg_black=$(tput setaf 0)
  fg_red=$(tput setaf 1)
  fg_green=$(tput setaf 2)
  fg_yellow=$(tput setaf 3)
  fg_blue=$(tput setaf 4)
  fg_magenta=$(tput setaf 5)
  fg_cyan=$(tput setaf 6)
  fg_white=$(tput setaf 7)

  fg_b_black=$(tput bold)$(tput setaf 0)
  fg_b_red=$(tput bold)$(tput setaf 1)
  fg_b_green=$(tput bold)$(tput setaf 2)
  fg_b_yellow=$(tput bold)$(tput setaf 3)
  fg_b_blue=$(tput bold)$(tput setaf 4)
  fg_b_magenta=$(tput bold)$(tput setaf 5)
  fg_b_cyan=$(tput bold)$(tput setaf 6)
  fg_b_white=$(tput bold)$(tput setaf 7)

  bg_black=$(tput setab 0)
  bg_red=$(tput setab 1)
  bg_green=$(tput setab 2)
  bg_yellow=$(tput setab 3)
  bg_blue=$(tput setab 4)
  bg_magenta=$(tput setab 5)
  bg_cyan=$(tput setab 6)
  bg_black=$(tput setab 7)
}

function cygwin_color {

  c_bold='\x1b[1m'
  c_end='\x1b[0m'

  fg_black='\x1b[0;30m'
  fg_red='\x1b[0;31m'
  fg_green='\x1b[0;32m'
  fg_yellow='\x1b[0;33m'
  fg_blue='\x1b[0;34m'
  fg_magenta='\x1b[0;35m'
  fg_cyan='\x1b[0;36m'
  fg_white='\x1b[0;37m'

  fg_b_black='\x1b[1;30m'
  fg_b_red='\x1b[1;31m'
  fg_b_green='\x1b[1;32m'
  fg_b_yellow='\x1b[1;33m'
  fg_b_blue='\x1b[1;34m'
  fg_b_magenta='\x1b[1;35m'
  fg_b_cyan='\x1b[1;36m'
  fg_b_white='\x1b[1;37m'

  bg_black='\x1b[40m'
  bg_red='\x1b[41m'
  bg_green='\x1b[42m'
  bg_yellow='\x1b[43m'
  bg_blue='\x1b[44m'
  bg_magenta='\x1b[45m'
  bg_cyan='\x1b[46m'
  bg_black='\x1b[47m'
}

if [[ $TERM =~ ^xterm ]]; then
  xterm_color
elif [ $TERM = 'cygwin' ]; then
  cygwin_color
fi
