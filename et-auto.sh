#!/usr/bin/env bash
# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Default
DefaultColor='\e[39m'   # Default foreground color

echo -ne '\033c'
echo -e ${Cyan}   "    +${Yellow}------------------------------------------------------------------${Cyan}+"
echo -e ${Yellow}   "    |                                                                  |"
echo -e "     |$Red    ███████╗████████╗    ${Green}█████╗ ██╗   ██╗████████╗ ██████╗ ${Purple}██╗   $Yellow |"
echo -e "     |$Red    ██╔════╝╚══██╔══╝   ${Green}██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗${Purple}██║   $Yellow |"
echo -e "     |$BRed    █████╗     ██║${White}█████╗${BGreen}███████║██║   ██║   ██║   ██║   ██║${BPurple}██║   $Yellow |"
echo -e "     |$BRed    ██╔══╝     ██║${White}╚════╝${BGreen}██╔══██║██║   ██║   ██║   ██║   ██║${BPurple}╚═╝   $Yellow |"
echo -e "     |$Red    ███████╗   ██║      ${Green}██║  ██║╚██████╔╝   ██║   ╚██████╔╝${Purple}██╗   $Yellow |"
echo -e "     |$Red    ╚══════╝   ╚═╝      ${Green}╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ${Purple}╚═╝   $Yellow |"
echo -e ${Yellow}   "    |                                                                  |"
echo -e ${Cyan}   "    +${Yellow}------------------------------------------------------------------${Cyan}+${Yellow}"
echo -e "                        |${BRed} Evil${BYellow} Twin${BPurple} Automated${BGreen} Attack${Yellow} |"
echo -e "                        ${Cyan}+${Yellow}----------------------------${Cyan}+"