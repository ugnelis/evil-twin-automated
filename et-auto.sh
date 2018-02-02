#!/usr/bin/env bash

# Regular colors.
BLACK='\e[0;30m'        # black
RED='\e[0;31m'          # red
GREEN='\e[0;32m'        # green
YELLOW='\e[0;33m'       # yellow
BLUE='\e[0;34m'         # blue
PURPLE='\e[0;35m'       # purple
CYAN='\e[0;36m'         # cyan
WHITE='\e[0;37m'        # white

# Bold colors.
BOLD_BLACK='\e[1;30m'       # black
BOLD_RED='\e[1;31m'         # red
BOLD_GREEN='\e[1;32m'       # green
BOLD_YELLOW='\e[1;33m'      # yellow
BOLD_BLUE='\e[1;34m'        # blue
BOLD_PURPLE='\e[1;35m'      # purple
BOLD_CYAN='\e[1;36m'        # cyan
BOLD_WHITE='\e[1;37m'       # white

# Default
DEFAULT_FOREGROUND_COLOR='\e[39m'   # Default foreground color.

echo -ne '\033c'
echo -e ${CYAN}   "    +${YELLOW}------------------------------------------------------------------${CYAN}+"
echo -e ${YELLOW}   "    |                                                                  |"
echo -e "     |${RED}    ███████╗████████╗    ${GREEN}█████╗ ██╗   ██╗████████╗ ██████╗ ${PURPLE}██╗   ${YELLOW} |"
echo -e "     |${RED}    ██╔════╝╚══██╔══╝   ${GREEN}██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗${PURPLE}██║   ${YELLOW} |"
echo -e "     |${BOLD_RED}    █████╗     ██║${WHITE}█████╗${BOLD_GREEN}███████║██║   ██║   ██║   ██║   ██║${BOLD_PURPLE}██║   ${YELLOW} |"
echo -e "     |${BOLD_RED}    ██╔══╝     ██║${WHITE}╚════╝${BOLD_GREEN}██╔══██║██║   ██║   ██║   ██║   ██║${BOLD_PURPLE}╚═╝   ${YELLOW} |"
echo -e "     |${BOLD_RED}    ███████╗   ██║      ${GREEN}██║  ██║╚██████╔╝   ██║   ╚██████╔╝${PURPLE}██╗   ${YELLOW} |"
echo -e "     |${BOLD_RED}    ╚══════╝   ╚═╝      ${GREEN}╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ${PURPLE}╚═╝   ${YELLOW} |"
echo -e ${YELLOW}   "    |                                                                  |"
echo -e ${CYAN}   "    +${YELLOW}------------------------------------------------------------------${CYAN}+${YELLOW}"
echo -e "                        |${BOLD_RED} Evil${BOLD_YELLOW} Twin${BOLD_PURPLE} Automated${BOLD_GREEN} Attack${YELLOW} |"
echo -e "                        ${CYAN}+${YELLOW}----------------------------${CYAN}+"

