#!/bin/bash
# unplugdrive.sh
#
# Allows safe unplugging of removable storage devices.
# Handles simultaneous selection of multiple drives
# Checks whether devices can safely get unmounted
# Unmounts all mounted partitions on nominated drive(s)
# Checks whether mountpoints failed unmounting
# spins down true rotational devices
#
# If user is expected to be able to start unplugdrive without being asked for entering his sudo password, it is necessary to add unplugdrive to the /etc/sudoers.d file with the "NOPASSWORD" option from ver. 0.82c and above.
# System settings referring to unplugdrive need to get supplemented by sudo preceding unplugdrive from ver. 0.82c and above. If etc/sudoers.d/antixers is modified at the same time, user won't notice any difference of operation compared to precvious version 0.82.
# Additionally an alias like "alias unplugdrive='sudo unplugdrive.sh'" and/or "alias unplugdrive.sh='sudo unplugdrive.sh'" should be added to system settings for user convenience, from ver 0.82c and above.
#
# Requires true bash (tested on GNU bash, Version 5.0.3(1)-release (i686-pc-linux-gnu))
# Dependencies: GNU bash, yad, pmount, sudo, whoami, findmnt, mapfile, grep, cut, lsblk, sort, sync, tr, sed, rev, cat, pidof, kill, hdparm, cryptsetup, awk, find
# Requires /etc/udev/rules.d/99-usbstorage.unused to be renamed 99-usbstorage

# bobc 12/28/19 added safemode, default FALSE, to avoid confirmation dialogs
# ppc 20/11/2020 - changed some design, making the dialog windows seem more "inbuit" with the OS, added time out to warning messages, and a title to the windows... cleaned up a bit the selection dialog so it's more multi-lingual...
# Robin.antiX 04/14/2021 new feature: debug mode structure added for easier testing.
# Robin.antiX 04/14/2021 bugfix: script did not unmount drives mounted to multiple mountpoints correctly, reporting to user it was safe to unplug while device was still mounted. First fixings by streamlining the processing.
# Robin.antiX 04/14/2021 bugfix: script did not unmount drives containing underline character "_" in mountpoint (happened always when parition-lable contained this character); fixed by removing seperator replacement and added different IFS instead.
# Robin.antiX 04/18/2021 bugfix: script did failed unmounting any usb drives not visable to df command, fixed by adding -a option.
# Robin.antiX 04/18/2021 bugfix: when more than 2 devices were to be unmounted lower checkboxes not accessible when using classical 3-button mouse. Slider at right side without function, so fixed by deriving window hight from number of drives/mountpoints displayed.
# Robin.antiX 04/18/2021 GUI behaviour: added -center to yad dialogs to prevent script windows to pop up in random, unforseeable places somewhere on screen. Moreover white borderless windows randomly scattered on white background from other open documents, resulting in text messages hiding within other text.
# Robin.antiX 04/18/2021 new features: commandline switches for help, safemode, decorations and debugging. Added taskbar icon in order to prevent yad from using its erlenmeyer flask.
# Robin.antiX 04/18/2021 bugfix: wrong entries in drivelist replaced (should have been TRUE/FALSE instead of position number for initialising checkboxes correctly)
# Robin.antiX 04/20/2021 bugfix: check for remaining devices, did still not reliably detect leftover mountpoints.
# Robin.antiX 04/20/2021 bugfix: deriving amount of time needed for sync from system info instead of fixed value; moreover before the delay window was not closing after sync due to “$!” mismatch of yad pids.
# Robin.antiX 05/04/2021 new feature: "centred" optional for users preferring opening windows near mouse pointer. Additional command line option: -c or --centred.
# Robin.antiX 05/06/2021 bugfix: replaced „pmount” by „umount” command for actual unmounting devices for several issues (pmount mixing up mountpoints for identical partitions and unfounded "Error: could not determine real path of the device" messages.)
# Robin.antiX 06/08/2021 bugfix: mechanical (rotational) USB hdds did not spun down after unmounting, so it was not safe to unplug them wheras script tells user it was. Therefore it was neccessary to change default behaviour from “unsafe” to “safe” so user has to deactivate support for spinning devices actively by passing -u or -i option.
# Robin.antiX 06/13/2021 bugfix: complete code rewrite for ver. 0.84 , geting rid of confusing variety of unconnected lists, replacing them by correlated arrays. New engine design allows to handle mountpoints containing blanks, and check for nested mounts (e.g. used on antiX live systems). New clear dialog design, so no extra confirmation dialogs needed anymore.
# Robin.antiX 10/21/2021 new feature in ver 0.90: supports closing of luks encrypted partitions.
# Robin.antiX 10/21/2021 unplugdrive ver. 0.91 is able to run with sudo and without as well. Some of its features may still not work without using sudo, waiting for specialy crafted pumount version.
# nXecure - 2021-10-24 Reduced complexity, separated stages and other blocks into functions, improved performance and reuse pmount for non-sudo
# Robin.antiX 11/18/2021 display bugfix ver. 0.93a: unmounted mointpoints listed in final message are not properly separated into partitions, showing all of them more than once.

### Please Note: text strings for debug output dont't need to get marked for translation.


# 0.) Preliminaries
#-------------------

# Variable declaration and setting of default values
TEXTDOMAINDIR=/usr/share/locale
TEXTDOMAIN=unplugdrive

title=$"Unplug USB device"
version="0.93b"
txt_version=$"Version "$version                    #text string for translation

icon_taskbar="/usr/share/icons/numix-square-antix/48x48/devices/usbpendrive_unmount.png"
falback_icon="/usr/share/icons/Adwaita/48x48/devices/media-removable.png"
[ ! -f "$icon_taskbar" ] && icon_taskbar="$falback_icon"

tempfile_01="$(mktemp -p /dev/shm)"
#debuglog="$HOME/unplugdrive-debug-$(date +%d%m%Y%H%M%S).log"    # function to write a logfile not implemented yet

# Arrays
count_items=0         # stores number of items found in correlated arrays (A)...(I).
block_name_array=()   #(A)    # e.g. sdc, sdb, mmcblck3
device_block_array=() #(B)    # e.g. /dev/sdc, /dev/sdb, /dev/mmcblck3
device_name_array=()  #(C)    # e.g. sdc4, sdb2, mmcblck3p1
device_path_array=()  #(D)    # e.g. /dev/sdc4 /dev/mmcblck3p1
mount_point_array=()  #(E)    # e.g. /media/demo/sdd4-usb-256MB_USB2.0Flas, /media/demo/mmcblk3p1-mmc-SD02G_0x35962817, 

# Variables
main_user_dialog=""                                # takes the complete yad command created on runtime for user dialog.
summarylist=""                                     # informational list for display purpose
txt_rotationalerror=""                             # informational list for display purpose
flag_debugmode=0                                   # functional flag changed by command line argument
flag_dryrun=0                                      # functional flag changed by command line argument
flag_ignore_rotational=0                           # functional flag changed by command line argument
flag_nosudo=false                                  # functional flag changed by detection of sudo status
flag_exclude=false                                 # functional flag changed by command line argument
flag_unsafe="false"                                # referring to default mode/unsafe mode, changed by command line argument
decorations="--undecorated"                        # referring to default yad dialog decorations (changed by command line argument)
centred=""                                         # referring to default dialog display position centred/near mouse, changed by command line argument
scroll="--fixed"                                   # referring to default dialog style without/with scrollbars, changed by command line argument
flat=false                                         # referring to default dialog style with/without separator lines between listed devices in main dialog
CHR_0x0A="$(printf '\nx')"; CHR_0x0A=${CHR_0x0A%x} # create special separator
true_user=$SUDO_USER                               # variable takes actual role of user starting the script (root/normal user name)
orig_IFS="$IFS"                                    # store original field seperator

# Text strings for translation
txt_on=$"on"                                       # refers to message “<partition> on <mountpoint>” presented in dialog to make it translatable.
txt_dlg_blocked=$"Blocked by nested mount"         # refers to message in user dialog informing about greyed out (deactivated) device for unmount.
txt_dlg_header=$"Mounted USB Partitions"
txt_dlg_instruction=$"Choose the drive(s) to be unplugged:"
txt_dlg_encrypted=$"Encrypted devices — will get closed if selected for unplugging."
txt_dlg_device=$"Device"
txt_dlg_button_1=$"Abort"
txt_dlg_button_4=$"Proceed"


main() {
    # check for commandline options
    txt_cline="$*"
    while [[ $# -gt 0 ]]
    do
      opt_cline="$1"
      case $opt_cline in
        -h|--help)        usage
                          exit 0;;
        -d|--decorated)   decorations=""
                          shift;;
        -c|--centred)     centred="--center"
                          shift;; 
        -s|--scrollbars)  scroll="--scroll"
                          shift;;
        -f|--flat)        flat=true
                          shift;;                          
        -u|--unsafe)      flag_unsafe="true"
                          shift;;
        -i|--ignore)      flag_ignore_rotational=1
                          shift;;
        -g|--debug)       flag_debugmode=1
                          shift;;
        -p|--pretend)     flag_dryrun=1
                          shift;;
        -x|--exclude)     flag_exclude=true
                          shift;;
         *)               echo -e $"Invalid command line argument. Please call\nunplugdrive -h or --help for usage instructions."
                          exit 1;;
      esac
    done

    echo_debug "Version:\t$version\nDebug mode: on""\n$txt_cline\nsafemode:\t$flag_unsafe\ndecorations:\t$decorations\ncentred:\t$centred\nflat display mode:\t$flat\nscrollbars:\t$scroll\ndryrun (pretend):\t$flag_dryrun\nignore rotationals:\t$flag_ignore_rotational\nExclude sd/mmc devices:\t$flag_exclude\nTrue user:\t$true_user\nexecuted by:\t`whoami`"

    # check whether unplugdrive is run with sudo by normal user.
    if [ `whoami` != "root" ]; then
        echo $"“unplugdrive” can also be run with SUDO for utilising different methods while processing."
        flag_nosudo=true
        true_user="${true_user:-$(whoami)}"
    else
        flag_nosudo=false
    fi

    # check for needed helper programs etc.:
    [ ! $(command -v yad) ] && echo -e $"\nˮyadˮ is not installed.\n   --> Please install ˮyadˮ before executing this script.\n" && exit 1
    
    # Remark for maintenance: this script uses arrays, which is BASH specific and not POSIX compliant.
    # If you want to port this script to a POSIX compliant shell, then replace the arrays with lists in variables or files.
    # You may also need to replace some bash-isms
    
    # Starting the real program, one stage at a time
    stage_1 # Stage 1: Gather device information
    stage_2 # Stage 2: Device selection dialog
    stage_3 # Stage 3: sync devices to not lose information
    stage_4 # Stage 4: Unmounting selected devices.
    stage_5 # Stage 5: Show results and exit
}

usage() {
    echo ""
    echo $"  Unplugdrive" "($txt_version)"
    echo ""
    echo -e $"  GUI tool for safely unplugging removable USB devices."
    echo ""
    echo $"  Usage: unplugdrive.sh [options]"
    echo ""
    echo $"  Options:"
    echo -e $"\t-h or --help\t\tdisplays this help text"
    echo -e $"\t-u or --unsafe\t\truns script in unsafe mode,\n\t            \t\tomiting some checks and dialogs"
    echo -e $"\t-i or --ignore\t\tignores whether devices are\n\t            \t\treported as rotational even in\n\t            \t\tdefault mode. No spindown."
    echo -e $"\t-x or --exclude\t\texclude sd-cards and mmc-devices\n\t            \t\tfrom detection"
    echo -e $"\t-d or --decorated\tuses window decorations"
    echo -e $"\t-c or --centred\t\topen dialogs centred"
    echo -e $"\t-s or --scrollbars\tuse scrollbars in main dialog window"
    echo -e $"\t-f or --flat\t\tdon't draw separator lines in main\n\t            \t\tdialog window for a flat design"
    echo -e $"\t-g or --debug\t\tenable debug output (terminal)"
    echo -e $"\t-p or --pretend\t\tdry run, don't actually un-\n\t            \t\tmount drives (for debugging)"
    echo -e ""
    echo -e $"  NEVER use the options -u and -i on rotational devices!"
    echo ""
    echo -e $"  If unplugdrive fails on your device you may call it using\n  SUDO, which will utilise different methods while processing."
    echo ""
    echo -e $"  Questions, Suggestions and Bugreporting please to:"
    echo -e "\t<forum.antiXlinux.com>"
    echo -e ""
    echo -e "  Copyright 2011, 2012-2018 SamK, anticapitalista" # entry needed to comply with EU legislation
    echo -e "  Copyright 2019, 2020, 2021 the antiX comunity"   # entry needed to comply with EU legislation
    echo -e ""                                                  # This GPL text may not get translated. See gnu.org for details.
    echo -e "  This program is free software: you can redistribute it and/or"
    echo -e "  modify it under the terms of the GNU General Public License as"
    echo -e "  published by the Free Software Foundation, either version 3 of"
    echo -e "  the License, or (at your option) any later version."
    echo ""
    echo -e "  This program is distributed in the hope that it will be useful,"
    echo -e "  but WITHOUT ANY WARRANTY; without even the implied warranty of"
    echo -e "  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the"
    echo -e "  GNU General Public License for more details."
    echo ""
    echo -e "  You should have received a copy of the GNU General Public"
    echo -e "  License along with this program.  If not, see "
    echo -e "  \t<http://www.gnu.org/licenses/>."
    echo ""
}

echo_debug()
{
    [ $flag_debugmode == 1 ] && echo -e "$*"
}

# preparing cleanup on leaving
cleanup() {
    [ -e $tempfile_01 ] && rm -f $tempfile_01
    IFS="$orig_IFS"
    echo_debug "cleaning up!"
    return 0
}
trap cleanup EXIT

# prepare safemode message
safemode() {
    if [ "$flag_unsafe" = "false" ]; then
      sudo -u $true_user -- yad --title="$title" --fixed $centred --timeout=3 --mouse $decorations \
          --window-icon="$icon_taskbar" \
          --text=$"<b>Aborting</b> on user request\n<b>without unmounting.</b>" \
          --no-buttons
      buttonselect=$?
      [ $buttonselect == 252 ] || [ $buttonselect == 255 ] && buttonselect=1
      [ $buttonselect == 70 ] && buttonselect=1
    fi
    return 0
}

get_devices() {
    local BLOCK_DEVICE="${1}"
    local DEVICES="$(lsblk -no PATH,TYPE "$BLOCK_DEVICE" | awk '{print $1}')"
    [ ! -z "$DEVICES" ] && echo "$DEVICES"
}

get_block_devices() {
	local DEVICE="$@"
	[ -z "$DEVICE" ] && return 0
	local BLOCK_DEVICE="$(lsblk -no pkname $DEVICE)"
	[ ! -z "$BLOCK_DEVICE" ] && echo "$BLOCK_DEVICE"
}

get_mount_points() {
    local MOUNT_SOURCE="${1}"
    local MOUNT_POINTS="$(findmnt -lno TARGET "$MOUNT_SOURCE")"
    [ ! -z "$MOUNT_POINTS" ] && echo "$MOUNT_POINTS"
}

#These functions return exit codes: 0 = found, 1 = not found
check_nested() {
    mount | grep ^"$1" >/dev/null;
}

check_rotational() {
    local ROTATIONAL=$(cat "/sys/block/${1}/queue/rotational")
    [ ! -z "$ROTATIONAL" ] && [ $ROTATIONAL -eq 1 ] && return 0
    return 1
}

check_encrypted() {
    [ $(lsblk -no TYPE "$1" | grep -xc "crypt") -gt 0 ] && return 0
    /sbin/cryptsetup isLuks "$1" 1>/dev/null 2>/dev/null && return 0
    return 1
}

is_usb(){
    local DISK_TYPE
    DISK_TYPE="$(find /dev/disk/by-id/ -lname "*$1" | sed 's#.*/##' | cut -d"-" -f1)"
    [ "$DISK_TYPE" = "usb" ] && return 0
    return 1
}

is_sd(){
    local DISK_TYPE
    DISK_TYPE="$(find /dev/disk/by-id/ -lname "*$1" | sed 's#.*/##' | cut -d"-" -f1)"
    if ! $flag_exclude && [ "$DISK_TYPE" = "mmc" ] && $(pmount | grep /dev/$1 >/dev/null 2>/dev/null); then
        return 0
    else
        return 1
    fi
}


has_mount_points(){
    local MOUNT_POINT_LIST
    MOUNT_POINT_LIST="$(lsblk -no MOUNTPOINT $1 | sort -u | grep -v "^$")"
    [ ! -z "$MOUNT_POINT_LIST" ] && return 0
    return 1
}

is_dev_mounted() {
    findmnt -rno SOURCE "$1" 1>/dev/null 2>/dev/null;
}

# prepare error message for unclosed encrypted partitions
close_encrypt_error() {
    sudo -u $true_user -- yad --title="$title" --fixed $centred --mouse $decorations --borders=10 \
          --window-icon="$icon_taskbar" \
          --text "<b><big>"$"Closing Encryption failed.""</big></b>\n""<span foreground='red'><u><b>"$"The following encrypted partition(s) could not get closed:""</b></u></span>\n\t$1\n<b>"$"Please make sure these are closed before proceeding!""</b>.\n "$"If you can't close an encrypted device, please abort unmounting.""\n" \
          --button=$"Abort unmounting":4 --button=$"I have closed them now. Proceed":6
    buttonselect=$?
    [ $buttonselect == 252 ] || [ $buttonselect == 255 ] && buttonselect=4
    [ $buttonselect == 70 ] && buttonselect=4
    if [ $buttonselect == 4 ]; then
        exit 1
    fi
    return 0
}

# 1.) Gather information about unpluggable devices and analysis for both, unmounting and user dialog:
#----------------------------------------------------------------------------------------------------
# Using find in /dev/disk/by-id/ to figure out if a block device is USB or not.
# Then it checks if it has mounted points. If both pass, it saves the block name.
stage_1() {
    local BLOCK_LIST PMOUNT_LIST BLOCK_PATH
    
    echo_debug "\n1.) Searching for USB block devices\n-----------------------------------\n"
    
    # 1.1) Get list of BLOCK DEVICES (only USB)
    # Arrays used:
    # block_name_array (each element is a unique device block, found to be USB and have mount points).
    echo_debug "1.1) Check if any USB device is mounted"
    BLOCK_LIST="$(lsblk -d -rno NAME)"
    PMOUNT_LIST="$(pmount | grep /dev/ | cut -d" " -f1 | sort -u )"
    [ ! -z "$PMOUNT_LIST" ] && PMOUNT_LIST="$(get_block_devices $PMOUNT_LIST | sort -u)"
    
    while read -r block; do
        # If block device empty, jump to next device block
        [ -z "$block" ] && continue
        
        # Check if it is a USB or SD device
        if is_usb "$block" ;  then
            echo_debug "$block is an USB device."
        elif is_sd "$block"; then
            echo_debug "$block is a SD device."
        elif [ ! -z "$PMOUNT_LIST" ] && [ $(echo "$PMOUNT_LIST" | grep -xc "$block") -gt 0 ];  then
            echo_debug "$block is listed in pmount."
        else
            continue
        fi
        
        # Check if it has mounted points
        BLOCK_PATH="/dev/$block"
        has_mount_points "$BLOCK_PATH" || continue
        echo_debug "  Mount points found. Saving $block to array ..."
        block_name_array+=("$block")
    done < <(echo "$BLOCK_LIST")
    
    # Count the amount of USB device blocks with mount points
    count_items="${#block_name_array[@]}"

    # 1.2) Check if no device was found and display an information message
    echo_debug "1.2) Checking USB blocks with mount points found: \nTotal number of items (\$count_items):\t$count_items"
    if [ $count_items -eq 0 ]; then
        sudo -u $true_user -- yad --title="$title" --fixed $centred --timeout=5 --mouse $decorations \
           --window-icon="$icon_taskbar" \
           --text $"A removable drive with a mounted\npartition was not found.\n<b>It is safe to unplug the drive(s)</b>" \
           --no-buttons
        exit 0
    fi

    # 1.3.) store basic properties of found devices to compound arrays:
    # Arrays Used in steps 1 to 4:
    #     └─ device_block_array (each element corresponds to the device block path of a mount point)
    # Arrays Used in steps 1 to 2: (only used for building the dialog)
    #     └─ device_name_array  (each element corresponds to the device character name of a mount point)
    #     └─ device_path_array  (each element corresponds to the device character name of a mount point)
    #     └─ mount_point_array  (each element corresponds to the unique path of a mount point)
    v=0
    encrypt=false
    echo_debug "1.3) Building arrays"
    # Check one device block at a time
    while [ $v -lt $count_items ]; do
        # Block device path:
        BLOCK_PATH="/dev/${block_name_array[$v]}"
        echo_debug "Processing: $BLOCK_PATH ..."
        RELATED_DEVICES="$(get_devices "$BLOCK_PATH")"
        
        # Jump to next block device if this one has no partitions
        [ -z "$RELATED_DEVICES" ] && let $((v++)) && continue
        echo_debug "For device block $BLOCK_PATH:"
        
        # Check one device at a time
        while read -r device; do
            DEV_PATH="$device"
            MOUNTED_DEVICES="$(get_mount_points "$device")"
            
            # Jump to next device if not mounted
            [ -z "$MOUNTED_DEVICES" ] && continue
            echo_debug "  $device was found mounted in"
            
            # Saving all mountpoints to arrays
            while read -r mountpoint; do
                device_block_array+=("$BLOCK_PATH")
                device_name_array+=("${device##*/}")
                device_path_array+=("$device")
                mount_point_array+=("$mountpoint")
                echo_debug "        └─ $mountpoint"
                mountpoints_paths[$v]="${mountpoints_paths[$v]}$mountpoint|"
                mountpoints_partitions[$v]="${mountpoints_partitions[$v]}$device|"

                # Check if device should be blocked
                check_nested "$mountpoint" && \
                DISABLED_BLOCKS="$DISABLED_BLOCKS"$'\n'"${block_name_array[$v]}" && \
                echo_debug "            └─ nested"
                
                # Check if partition is encrypted
                check_encrypted "$device" && encrypt=true && \
                echo_debug "            └─ encrypted"
            done < <(echo "$MOUNTED_DEVICES")
        done < <(echo "$RELATED_DEVICES")
        let $((v++))
    done
    # Get unique blocks that shouldn't be unmounted
    [ ! -z "$DISABLED_BLOCKS" ] && DISABLED_BLOCKS="$(echo "$DISABLED_BLOCKS" | sort -u)"
}

# 2.) User dialog for selection
# -----------------------------
stage_2() {
    
    # LEGO blocks for main dialog
    yad_piece() {
        local DEVICE_CATEGORY="${1}"
        local YAD_ITEM="${2}"
        local FIELD_STATE="${3}"
        case $DEVICE_CATEGORY in
             block) echo "    --field=\"$txt_dlg_device ${YAD_ITEM}\":CHK '${FIELD_STATE}'";;
            device) echo "    --field=\"\t${YAD_ITEM}\":LBL '${FIELD_STATE}'";;
          mntpoint) echo "    --field=\"\t\t\t${YAD_ITEM}\":LBL '${FIELD_STATE}'";;
        esac
    }
    
    echo_debug "\n2.) Dialog window\n-----------------"
    # build up a string variable containing complete yad window command
    main_user_dialog=$(echo -e "sudo -u $true_user -- yad $centred --mouse \\
    --title=\"$title\" --width=250 --height=300 \\
    --window-icon=\"$icon_taskbar\" $decorations --borders=5 \\
    --form $scroll --separator=\"|\" --item-separator=\"|\" \\")
    main_user_dialog="$main_user_dialog$(echo -e "\n    --field=\"<b><big>$txt_dlg_header</big>\n$txt_dlg_instruction</b>\":LBL" \'\')"
    if ! $flat; then dialog_separator="$(echo -e " \\\n    --field=\"\":LBL \\")"; else dialog_separator=" \\"; fi
    v=0
    local OLD_BLOCK OLD_DEVICE NEW_BLOCK NEW_DEVICE NEW_MOUNT_POINT
    local YAD_ITEM YAD_STATE new_dialog
    # Creating the yad dialog based on the content of the arrays
    while [ $v -lt ${#device_block_array[@]} ]; do
        NEW_BLOCK="${device_block_array[$v]}"
        NEW_BLOCK="${NEW_BLOCK##*/}"
        NEW_DEVICE="${device_name_array[$v]}"
        NEW_MOUNT_POINT="${mount_point_array[$v]}"
        if [ "$NEW_BLOCK" != "$OLD_BLOCK" ]; then
            if [ $(echo "$DISABLED_BLOCKS" | grep -xc "$NEW_BLOCK") -gt 0 ]; then
                YAD_ITEM="$NEW_BLOCK ($txt_dlg_blocked)"
                YAD_STATE="@disabled@"
            else
                YAD_ITEM="$NEW_BLOCK"
                YAD_STATE=""
            fi
            new_dialog="$(yad_piece "block" "$YAD_ITEM" "$YAD_STATE")"
            main_user_dialog="$main_user_dialog$dialog_separator"$'\n'"$new_dialog"
            
            OLD_BLOCK="$NEW_BLOCK"
        fi
        
        if [ "$NEW_DEVICE" != "$OLD_DEVICE" ]; then
            YAD_ITEM="<u>$NEW_DEVICE</u>\t$NEW_MOUNT_POINT"
            # Special case for encrypted devices
            check_encrypted "${device_path_array[$v]}" && YAD_ITEM="<u>$NEW_DEVICE</u>*\t$NEW_MOUNT_POINT"
            new_dialog="$(yad_piece "device" "$YAD_ITEM" "$YAD_STATE")"
            main_user_dialog="$main_user_dialog \\"$'\n'"${new_dialog}"
            
            OLD_DEVICE="$NEW_DEVICE"
        else
            YAD_ITEM="$NEW_MOUNT_POINT"
            new_dialog="$(yad_piece "mntpoint" "$YAD_ITEM" "$YAD_STATE")"
            main_user_dialog="$main_user_dialog \\"$'\n'"$new_dialog"
        fi
        let $((v++))
    done
    main_user_dialog="$main_user_dialog$dialog_separator"
    if $encrypt; then
        main_user_dialog=$main_user_dialog$(echo -e "\n    --field=\"* $txt_dlg_encrypted\":LBL \"@disabled@\" \\")
    fi
    main_user_dialog=$main_user_dialog$(echo -e "\n    --button=\"$txt_dlg_button_1\":1 \\")
    main_user_dialog=$main_user_dialog$(echo -en "\n    --button=\"$txt_dlg_button_4\":4")
    
    echo_debug "$main_user_dialog"

    # display dialog and analyse output
    while [ -z "$dlg_response" ]  # Don't proceed as long nothing was selected, or abort.
        do
        dlg_response="$(echo "$(eval "$main_user_dialog" | tr -s '|'; echo ${PIPESTATUS[0]})" | tr -d '\n')"            # here user dialog is actually displayed.
        buttonselect="$(echo "$dlg_response" | rev | cut -d "|" -f 1)"
        dlg_response="$(echo "$dlg_response" | rev | cut -d "|" -f 2- | rev )"
        if [ $(echo "$dlg_response" | grep "TRUE") ]; then
            dlg_response="$(echo "$dlg_response" | sed 's/^|//')"
        else
            dlg_response=""
        fi
        [ $buttonselect == 252 ] || [ $buttonselect == 255 ] && buttonselect=1        # Catch ESC button and X-icon also 
        [ $buttonselect == 1 ] && break
    done
    [ -z "$dlg_response" ] && safemode
    [ $buttonselect == 70 ] || [ $buttonselect == 1 ] && exit 1                                        # exit for both, normal and safe mode.
    echo_debug "\ndlg_response: $dlg_response\nbuttonselect: $buttonselect"
}

# 3.) Preparations for unmounting
#--------------------------------
# Since new main user dialog is arranged more clearly there is no chance user mixes up the check boxes
# The devices with nested mounts are blocked/disabled, (grayed out), so they cannot be selected.
stage_3() {

    # 3.1 sync before unplugging (Only if flag_unsafe=false
    # Sync device and ensure user waits long enough before unplugging so everything gets written to storage
    if [ "$flag_unsafe" = "false" ]; then
        echo_debug "\n3.) Preparations for unmounting\n-------------------------------"
        
        # Prepare YAD dialog
        CUSTOM_YAD_DIALOG=(
            --title="$title" --fixed $centred --mouse $decorations
            --progress --pulsate --auto-close
            --text=$"Data is being written\nto devices. <b>Please wait...</b>"
            --window-icon="$icon_taskbar"
            --no-buttons
        )
        
        # Write data to device(s)
        echo_debug "Syncing write cache to device ..."
        while true; do
            echo $"# sync ...";
            sudo -u $true_user -- sync
            
            # If the sync went properly, then exit loop
            if [ "$(cat /proc/meminfo | grep 'Dirty:' | tr -s ' ' | cut -d' ' -f 2)" == "0" ] && \
            [ "$(cat /proc/meminfo | grep 'Writeback:' | tr -s ' ' | cut -d' ' -f 2)" == "0" ]; then
                echo $"# Done" && sleep 0.5s
                break
            fi
        done | sudo -u $true_user -- yad "${CUSTOM_YAD_DIALOG[@]}"
    fi
}

# 4.) Unmounting selected devices
# -------------------------------
# During this step only the block_name_array is reused.
# Because, the user could have mounted other partitions while the "unplug"
# window was open, the script will search again for all mount points for
# the selected block devices in Step 2 and unmount them one at a time.
stage_4() {
    # unmount all mountpoints registered to a device with unmount flag set.
    echo_debug "\n4.) Unmounting\n--------------\nNumber of devices to unmount: $(echo "$dlg_response" | tr '|' '\n' |grep -c 'TRUE')"
    [ $flag_dryrun == 1 ] && echo -e "\033[1;33mDry run. Nothing was actually unmounted.\nOmit option -p for real operation.\033[0m"

    $flag_nosudo && echo "NOSUDO mode" || echo "SUDO mode"
    
    # run through devices while checking its unmount flag
    v=0
    local BLOCK_NAME BLOCK_PATH RELATED_DEVICES MOUNTED_DEVICES
    rm "$tempfile_01"
    while [ $v -lt $count_items ]; do
        # Only process block devices that were selected to be unmounted
        if [ "$(echo "$dlg_response" | cut -d '|' -f $(($v+1)))" == "TRUE" ]; then
            BLOCK_NAME="${block_name_array[$v]}"
            BLOCK_PATH="/dev/${BLOCK_NAME}"
            echo_debug "Processing: $BLOCK_PATH ..."
            RELATED_DEVICES="$(get_devices "$BLOCK_PATH")"
            
            # jump to next device block if this one is blocked (assurance)
            if [ $(echo "$DISABLED_BLOCKS" | grep -xc "BLOCK_NAME") -gt 0 ]; then
                echo_debug "This was a nested device. Skipping ..."
                let $((v++)) && continue
            fi
            
            # Jump to next block device if this one has no partitions
            [ -z "$RELATED_DEVICES" ] && let $((v++)) && continue
            echo_debug "For device block $BLOCK_PATH:"
            remove_device=true
            
            # Check one device at a time
            while read -r device; do
                encrypt=false # reset
                MOUNTED_DEVICES="$(get_mount_points "$device")"
                # Jump to next device if not mounted
                [ -z "$MOUNTED_DEVICES" ] && continue
                
                # Check if encrypted, and save name
                check_encrypted "$device" && encrypt=true
                
                # Unmount each mountpoint one at a time
                echo_debug "  $device - Unmounting ..."
                while read -r mountpoint; do
                    # SUDO mode
                    if ! $flag_nosudo; then
                        echo_debug umount "$mountpoint"
                        [ $flag_dryrun != 1 ] && umount "$mountpoint"
                    # NON-SUDO mode
                    else
                        echo_debug pumount --luks-force "$device"
                        [ $flag_dryrun != 1 ] && pumount --luks-force "$device"
                    fi
                    echo_debug "    └─ $mountpoint (unmounting ...)"
                done < <(echo "$MOUNTED_DEVICES")
                
                
                # Check if not completely unmounted and perform a last unmount
                if [ $flag_dryrun != 1 ] && is_dev_mounted "$device"; then
                    echo_debug "  Needed to perform extra unmount on $device"
                    # SUDO mode
                    echo_debug umount "$device"
                    [ ! $flag_nosudo ] && umount "$device"
                    # NON-SUDO mode
                    echo_debug pumount --luks-force "$device"
                    $flag_nosudo && pumount --luks-force "$device"
                fi
                
                # If device is encrypted, close luks
                if ! $flag_nosudo && $encrypt && [ ! -z "$device" ]; then
                    echo_debug "    └─ luksClose $device"
                    echo_debug cryptsetup luksClose "$device"
                    if [ $flag_dryrun != 1 ]; then
                        cryptsetup luksClose "$device" || close_encrypt_error "$device"
                    fi
                fi
                
                # If still not fully unmounted, then don't remove
                if [ $flag_dryrun != 1 ] && is_dev_mounted "$device"; then
                    remove_device=false
                    echo "<u>$txt_dlg_device $(echo $device | rev | cut -d/ -f1 | rev)</u>" >> "$tempfile_01"
                    while read item; do
                        echo "\t$item" >> "$tempfile_01"
                    done <<<"$(findmnt --list -n -o SOURCE,TARGET | grep $device | tr -s ' ' | cut -d ' ' -f 2-)"                    
                # If properly unmounted, then add to summary
                else
                    summarylist="$summarylist\n<u>$txt_dlg_device $(echo $device | rev | cut -d/ -f1 | rev)</u>"
                    w=1
                    while read -d'|' item; do
						if [ "$item" == "$device" ]; then
							summarylist="$summarylist\n\t$(echo "${mountpoints_paths[$v]}" | cut -d '|' -f $w  | tr '\t' '|' | tr -s '|' | sed 's/|$//;s/|/\n\t/g')"
						fi
						let $((w++))
                    done <<<"${mountpoints_partitions[$v]}"
                    
                fi
            done < <(echo "$RELATED_DEVICES")
            
            # Spin down and completely remove block device
            if [ $remove_device ]; then
                # SUDO mode
                if ! $flag_nosudo; then
                    if check_rotational "$BLOCK_NAME" && \
                    [ $flag_ignore_rotational -eq 0 ]; then
                        echo_debug "-- Spinning down $BLOCK_NAME"
                        echo_debug hdparm -Y "$BLOCK_PATH"
                        if [ $flag_dryrun != 1 ]; then
                            hdparm -Y "$BLOCK_PATH" || \
                            if ! echo "$txt_rotationalerror" | grep "$BLOCK_NAME"; then txt_rotationalerror="$txt_rotationalerror$BLOCK_NAME  "; fi
                        fi
                    fi
                # NON-SUDO mode
                elif $flag_nosudo; then
                    echo_debug "-- Removing block device $BLOCK_NAME"
                    echo_debug pumount -D "$BLOCK_PATH"
                    if [ $flag_dryrun != 1 ]; then
                        pumount -D "$BLOCK_PATH" || check_rotational "$BLOCK_NAME" && \
                        [ $flag_ignore_rotational -eq 0 ] && \
                        if ! echo "$txt_rotationalerror" | grep "$BLOCK_NAME"; then txt_rotationalerror="$txt_rotationalerror$BLOCK_NAME  "; fi
                    fi
                fi
            fi
        fi
        let $((v++))
    done
    
    echo_debug "\nUNMOUNT FINISHED\n"
}

# 5.) Final user dialog on exit
# -----------------------------
stage_5() {
    # Preparations for dialog window
    if [ ! -z "$txt_rotationalerror" ]; then
        successtext=$"<big><b>Unmounted:</b></big>\n$summarylist\n\nBut despite the following devices were reported to be rotational\nthey <span foreground='red'>did not respond to spindown command</span>:\n\t$txt_rotationalerror\nPlease check whether they are spun down before unplugging.\n<b>After rotational drives are spun down it is safe to unplug.</b>"
        yad_timeout=""
        yad_button="--button="OK""
    else
        successtext=$"<big><b>Unmounted:</b></big>\n$summarylist\n\n<b>It is safe to unplug the drive(s)</b>"
        yad_timeout="--timeout=5"
        yad_button="--no-buttons"
    fi

    # User information on exit:
    if [ -s "$tempfile_01" ];then
        # Display a message if unmount failed
        mountpointerrorlist="$(cat "$tempfile_01")"
        sudo -u $true_user -- yad --title="$title" --fixed $centred --mouse $decorations --borders=5 \
            --text=$"<b><big>Mountpoint removal failed.</big></b>\n<span foreground='red'><u><b>One or more mountpoin(s) remain present at:</b></u></span>""\n\n$mountpointerrorlist\n\n"$"<b>Check each mountpoint listed before unpluging the drive(s).</b>" \
            --window-icon="$icon_taskbar" \
            --button="OK"
        exit 1
    else
       # Display a message if unmount successful   
        sudo -u $true_user -- yad --title="$title" --fixed $centred $yad_timeout --mouse $decorations --borders=5 \
            --text="$successtext" \
            --window-icon="$icon_taskbar" \
            $yad_button
        exit 0
    fi
}

main "$@"
