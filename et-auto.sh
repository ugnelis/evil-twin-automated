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

###########################################
# Get WI-FI interfaces.
# Globals:
#   interface_list
# Arguments:
#   None
# Returns:
#   None
###########################################
get_interfaces_list() {
	unset interface_list
	for interface in $(ls -1 /sys/class/net); do
		if [ -f /sys/class/net/${interface}/uevent ]; then
			if $(grep -q DEVTYPE=wlan /sys/class/net/${interface}/uevent)
			then
				interface_list="${interface_list}\n ${interface}"
			fi
		fi
	done
	if [ -x "$(command -v iwconfig 2>&1)" ] && [ -x "$(command -v sort 2>&1)" ]; then
		for interface in $(iwconfig 2> /dev/null | sed 's/^\([a-zA-Z0-9_.]*\) .*/\1/'); do
			interface_list="${interface_list}\n ${interface}"
		done
		interface_list="$(printf "${interface_list}" | sort -bu)"
	fi
}

###########################################
# Check if needed programs are installed.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
###########################################
check_programs() {
    if [ -d /sys/bus/pci ] || [ -d /sys/bus/pci_express ] || [ -d /proc/bus/pci ]; then
        if [ ! -x "$(command -v lspci 2>&1)" ]; then
            echo -e ${WHITE}"[${RED}!${WHITE}]${GREEN} Please install ${BOLD_PURPLE}lspci{GREEN} from your distro's package manager${WHITE}."
            echo ""
            exit 1
        fi
    fi
    if [ -d /sys/bus/usb ]; then
        if [ ! -x "$(command -v lsusb 2>&1)" ]; then
            echo -e ${WHITE}"[${RED}!${WHITE}]${GREEN} Please install ${BOLD_PURPLE}lsusb${GREEN} from your distro's package manager${WHITE}."
            echo ""
            exit 1
        fi
    fi
}

main() {
    local result='main'
    while [ "${result}" == 'main' ];
    do
        result=none

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

        local user_name=`whoami`
        if [ "${user_name}" != "root" ]; then
            echo -e "${YELLOW}     +${WHITE}------------------------------------------------------------------${YELLOW}+"
            echo -e "${WHITE}     | [${RED}!${WHITE}] You need to launch the script as the root user, run it with  ${WHITE}|"
            echo -e "${YELLOW}     +${WHITE}------------------------------------------------------------------${YELLOW}+"
            echo -e "${WHITE}     | ${RED}                    \$${WHITE}=> sudo ${YELLOW}./${GREEN}et${WHITE}-${GREEN}auto${WHITE}.${GREEN}sh${WHITE}                        |"
            echo -e "${WHITE}     | ${RED}                    \$${WHITE}=> sudo ${BLUE}bash ${GREEN}et${WHITE}-${GREEN}auto${WHITE}.${GREEN}sh${WHITE}                     |"
            echo -e "${YELLOW}     +${WHITE}------------------------------------------------------------------${YELLOW}+"
            echo ""
            echo ""
        else
            check_programs

            echo -e "${YELLOW}     +${WHITE}------------------------------------------------------------------${YELLOW}+"
            echo -e "${WHITE}     | ${YELLOW} ID ${WHITE} |                            ${BOLD_PURPLE}Name${WHITE}                           |"
            echo -e "${YELLOW}     +${WHITE}------------------------------------------------------------------${YELLOW}+"
            echo -e "${WHITE}     | ${RED}[${YELLOW}01${RED}]${WHITE} |${GREEN} Start the attack${WHITE}.                                         |"
            echo -e "${WHITE}     | ${RED}[${YELLOW}02${RED}]${WHITE} |${GREEN} Exit${WHITE}.                                                     |"
            echo -e "${YELLOW}     +${WHITE}------------------------------------------------------------------${YELLOW}+"
            echo ""
            echo -e -n "${WHITE}    ${RED} [${CYAN}!${RED}]${WHITE} Type the${BOLD_RED} ID${WHITE} of your choice: "

            local menu_selection
            read menu_selection
            menu_selection=`expr ${menu_selection} + 0 2> /dev/null`

            case "${menu_selection}" in
                "1")
                    ;;
                "2")
                    echo ""
                    echo -e "${WHITE}     [${GREEN} ok ${WHITE}]${WHITE} See ${BOLD_YELLOW}you${WHITE} next time!"
                    echo ""
			        exit
			        ;;
			    *)
			        echo ""
			        echo -e "${WHITE}     [${RED}!${WHITE}]${RED} Input${WHITE} is out of range."
			        echo ""
			        sleep 2.0
			        result='main'
			        ;;
			esac
        fi
    done
}
main "$@"
