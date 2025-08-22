#!/bin/bash

############### RUNIT SERVICE MANAGER #################
#### Manage runit services with a simple graphical ####
####   interface. Add, remove, start or stop any   ####
####       available runit service and log.        ####
####   # Initially developed for antiX linux #     ####
#######################################################

### Localization ###
TEXTDOMAINDIR=/usr/share/locale
TEXTDOMAIN=runit-service-manager

if [[ ! -e /usr/bin/dialogbox ]]; then
    echo "dialogbox is NOT installed. Cannot start the script."
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    echo "RUNNING AS ROOT"
else
    echo "NOT RUNNING AS ROOT"
    exit 1
fi

if [[ $(ps -p1 | grep -ic "runit") -eq 0 ]]; then
    echo "runit is not PID 1"
    exit 1
fi

### Files and folders ###
SERVICE_DIRECTORY="/etc/service"
SERVICE_SOURCE="/etc/sv"
SERVICE_STATUS_LIST="$(mktemp -p /dev/shm)"
ICONS="/usr/share/icons/papirus-antix/48x48"
FALLBACK_ICONS="/usr/share/icons/Adwaita/48x48"
ICON_SIZE="48px"

ALL_SERVICES="$(ls -1 "$SERVICE_SOURCE")"

### MAIN ICONS ###
MAIN_WINDOW_ICON="$ICONS/devices/server-database.png"
MAIN_WINDOW_ICON="${MAIN_WINDOW_ICON:-$FALLBACK_ICONS/devices/computer.png}"
SERVICE_VITAL_ICON="$FALLBACK_ICONS/status/changes-prevent-symbolic.symbolic.png"
SERVICE_UP_ICON="$FALLBACK_ICONS/ui/checkbox-checked-symbolic.symbolic.png"
SERVICE_DOWN_ICON="$FALLBACK_ICONS/ui/window-close-symbolic.symbolic.png"
SERVICE_UNUSED_ICON="$FALLBACK_ICONS/ui/checkbox-symbolic.symbolic.png"
# vital services: dbus, elogind, getty-tty, slim, udevd
VITAL_SERVICES="getty-tty1
getty-tty2
slim
slimski
udevd"

### STRINGS OF TEXT ###
MAIN_WINDOW_TITLE=$"Runit Service Manager"
SERVICES_TEXT=$"Services"
SERVICE_TEXT=$"Service"
LOG_TEXT=$"Log"
ADD_SERVICE_TEXT=$"Add unused service"
VITAL_WARNING_TEXT=$"This is a VITAL service (it cannot be disabled)"
STATUS_TEXT=$"Status:"
STARTUP_TEXT=$"Startup:"
UP_STATUS_TEXT=$"Up"
DOWN_STATUS_TEXT=$"Down"
YES_STARTUP_TEXT=$"Yes"
NO_STARTUP_TEXT=$"No"
START_BUTTON_TEXT=$"Start"
RESTART_BUTTON_TEXT=$"Restart"
STOP_BUTTON_TEXT=$"Stop"
ENABLE_BUTTON_TEXT=$"Enable"
DISABLE_BUTTON_TEXT=$"Disable"
ADD_BUTTON_TEXT=$"Add"
REMOVE_BUTTON_TEXT=$"Remove"
RELOAD_BUTTON_TEXT=$"Reload"

cleanup() {
    ### Remove temporary files
    rm -f -- "$SERVICE_STATUS_LIST"
    echo "Cleanup and exiting"
}

### Set trap on EXIT for cleanup
trap cleanup EXIT

### FORCE RUNIT TO RESCAN FOR AVAILABLE SERVICES
runit_force_rescan(){
    sudo kill -SIGALRM 1 && sleep 1.5s
}

### UPDATE THE LIST OF LOADED SERVICES ###
update_service_list(){
    local SERVICE_NAME
    local SERVICE_STATUS
    local LOG_STATUS
    
    ALL_SERVICES="$(ls -1 "$SERVICE_SOURCE")"
    
    ENABLED_SERVICES="$(sudo sv status ${SERVICE_DIRECTORY}/* | grep "/" | awk '{print $1,$2,$6}' | sed 's#:.*/# #' | sed 's/://g')"
    
    # Save SERVICE_STATUS_LIST in correct order
    echo "$ENABLED_SERVICES" | awk '{print $2 " " $1 " " $3}' > "$SERVICE_STATUS_LIST"
}

reload_service_listbox(){
    # Do NOT regenerate the list if the services list file is empty
    if [[ ! -s "$SERVICE_STATUS_LIST" ]]; then return 1; fi
    
    local TEMP_LAYOUT=$(mktemp -p /dev/shm)
    local APROPIATE_ICON
    local SERVICE_NAME
    
    # clear current Service Listbox items and position
    echo "clear SERVICE_LISTBOX" >> "$TEMP_LAYOUT"
    echo "position onto SERVICE_LISTBOX" >> "$TEMP_LAYOUT"
    
    # Process each service at a time
    while read -r line; do
        APROPIATE_ICON=""
        SERVICE_NAME="$(echo "$line" | awk '{print $1}')"
        
        # If this service is vital, use apropiiate icon
        if [[ $(echo "$VITAL_SERVICES" | grep -c "^${SERVICE_NAME}$") -gt 0 ]]; then
            APROPIATE_ICON="$SERVICE_VITAL_ICON"
        # If this service is up, use apropiate icon
        elif [[ "$(echo "$line" | awk '{print $2}')" == "run" ]]; then
            APROPIATE_ICON="$SERVICE_UP_ICON"
        # If this service is down, use the propiate icon
        elif [[ "$(echo "$line" | awk '{print $2}')" == "down" ]]; then
            APROPIATE_ICON="$SERVICE_DOWN_ICON"
        fi
        echo "add item \"$SERVICE_NAME\" $APROPIATE_ICON" >> "$TEMP_LAYOUT"
    done < "$SERVICE_STATUS_LIST"
    
    # Return at the end of the file
    echo "position behind BOTTOM_FRAME" >> "$TEMP_LAYOUT"
    
    # Reposition list selection
    if [[ ! -z "$SERVICE_SELECTED" ]] && [[ $(grep -ic "^${SERVICE_SELECTED} " "$SERVICE_STATUS_LIST") -gt 0 ]]; then
        echo "set \"SERVICE_LISTBOX:$SERVICE_SELECTED\" current" >> "$TEMP_LAYOUT"
    fi
    
    # Export changes to dialogbox
    cat "$TEMP_LAYOUT" >&$OUTPUTFD
    
rm -f -- "$TEMP_LAYOUT"
}

# Check the service status
get_service_status(){
    local SELECTED_SERVICE="${1}"
    # Do nothing is no service selected
    if [[ -z "$SELECTED_SERVICE" ]]; then return 1; fi
    
    local TEMP_LAYOUT=$(mktemp -p /dev/shm)
    
    local SERVICE_ITEM="$(cat "$SERVICE_STATUS_LIST" | grep "^${SELECTED_SERVICE} ")"
    local SERVICE_STATUS="$(echo $SERVICE_ITEM | awk '{print $2}')"
    local LOG_STATUS="$(echo $SERVICE_ITEM | awk '{print $3}')"
    local SERVICE_STARTUP
    local LOG_STARTUP
    
    # Display status info
    echo "set SERVICE_NAME_TEXT text \"<big><b>${SELECTED_SERVICE}</b></big>\"" >> $TEMP_LAYOUT
    
    # Enable all buttons
    echo "hide START_SERVICE_BUTTON" >> $TEMP_LAYOUT
    echo "hide RESTART_SERVICE_BUTTON" >> $TEMP_LAYOUT
    echo "hide STOP_SERVICE_BUTTON" >> $TEMP_LAYOUT
    echo "hide START_LOG_BUTTON" >> $TEMP_LAYOUT
    echo "hide STOP_LOG_BUTTON" >> $TEMP_LAYOUT
    echo "hide ENABLE_SERVICE_BUTTON" >> $TEMP_LAYOUT
    echo "hide DISABLE_SERVICE_BUTTON" >> $TEMP_LAYOUT
    echo "hide ENABLE_LOG_BUTTON" >> $TEMP_LAYOUT
    echo "hide DISABLE_LOG_BUTTON" >> $TEMP_LAYOUT
    
    # Display service status information
    case "$SERVICE_STATUS" in
        run)
            SERVICE_STATUS="<b>${STATUS_TEXT}</b> $UP_STATUS_TEXT"
            echo "show STOP_SERVICE_BUTTON" >> $TEMP_LAYOUT
            echo "show RESTART_SERVICE_BUTTON" >> $TEMP_LAYOUT
            echo "enable STOP_SERVICE_BUTTON" >> $TEMP_LAYOUT;;
        down)
            SERVICE_STATUS="<b>${STATUS_TEXT}</b> $DOWN_STATUS_TEXT"
            echo "show START_SERVICE_BUTTON" >> $TEMP_LAYOUT
            echo "enable START_SERVICE_BUTTON" >> $TEMP_LAYOUT;;
        *)
            SERVICE_STATUS="<b>${STATUS_TEXT}</b> ?"
            echo "show START_SERVICE_BUTTON" >> $TEMP_LAYOUT
            echo "enable START_SERVICE_BUTTON" >> $TEMP_LAYOUT;;
    esac
    echo "set SERVICE_STATUS_TEXT text \"$SERVICE_STATUS\"" >> $TEMP_LAYOUT
    
    # Display log status information
    case "$LOG_STATUS" in
        run)
            LOG_STATUS="<b>${STATUS_TEXT}</b> $UP_STATUS_TEXT"
            echo "show STOP_LOG_BUTTON" >> $TEMP_LAYOUT
            echo "enable STOP_LOG_BUTTON" >> $TEMP_LAYOUT;;
        down)
            LOG_STATUS="<b>${STATUS_TEXT}</b> $DOWN_STATUS_TEXT"
            echo "show START_LOG_BUTTON" >> $TEMP_LAYOUT
            echo "enable START_LOG_BUTTON" >> $TEMP_LAYOUT;;
        *)
            LOG_STATUS="<b>${STATUS_TEXT}</b> ?"
            echo "show START_LOG_BUTTON" >> $TEMP_LAYOUT
            echo "enable START_LOG_BUTTON" >> $TEMP_LAYOUT;;
    esac
    echo "set LOG_STATUS_TEXT text \"$LOG_STATUS\"" >> $TEMP_LAYOUT
    
    # Get service startup information
    if [[ ! -f "${SERVICE_DIRECTORY}/${SELECTED_SERVICE}/down" ]]; then
        SERVICE_STARTUP="<b>${STARTUP_TEXT}</b> $YES_STARTUP_TEXT"
        echo "show DISABLE_SERVICE_BUTTON" >> $TEMP_LAYOUT
        echo "enable DISABLE_SERVICE_BUTTON" >> $TEMP_LAYOUT
    else
        SERVICE_STARTUP="<b>${STARTUP_TEXT}</b> $NO_STARTUP_TEXT"
        echo "show ENABLE_SERVICE_BUTTON" >> $TEMP_LAYOUT
        echo "enable ENABLE_SERVICE_BUTTON" >> $TEMP_LAYOUT
    fi
    echo "set SERVICE_STARTUP_TEXT text \"$SERVICE_STARTUP\"" >> $TEMP_LAYOUT
    
    # Get LOG startup information
    if [[ ! -d "${SERVICE_DIRECTORY}/${SELECTED_SERVICE}/log" ]]; then
        LOG_STARTUP="<b>${STARTUP_TEXT}</b> ?"
        echo "show ENABLE_LOG_BUTTON" >> $TEMP_LAYOUT
        echo "enable ENABLE_LOG_BUTTON" >> $TEMP_LAYOUT
    elif [[ ! -f "${SERVICE_DIRECTORY}/${SELECTED_SERVICE}/log/down" ]]; then
        LOG_STARTUP="<b>${STARTUP_TEXT}</b> $YES_STARTUP_TEXT"
        echo "show DISABLE_LOG_BUTTON" >> $TEMP_LAYOUT
        echo "enable DISABLE_LOG_BUTTON" >> $TEMP_LAYOUT
    else
        LOG_STARTUP="<b>${STARTUP_TEXT}</b> $NO_STARTUP_TEXT"
        echo "show ENABLE_LOG_BUTTON" >> $TEMP_LAYOUT
        echo "enable ENABLE_LOG_BUTTON" >> $TEMP_LAYOUT
    fi
    if [[ ! -d "${SERVICE_DIRECTORY}/${SELECTED_SERVICE}/log/supervise" ]]; then
		echo "disable START_LOG_BUTTON" >> $TEMP_LAYOUT
    fi
    echo "set LOG_STARTUP_TEXT text \"$LOG_STARTUP\"" >> $TEMP_LAYOUT
    
    # If the selected service is Vital, display the message and disable service buttons
    if [[ $(echo "$VITAL_SERVICES" | grep -c "^${SELECTED_SERVICE}$") -gt 0 ]]; then
        echo "show VITAL_WARNING_TEXT" >> $TEMP_LAYOUT
        echo "disable STOP_SERVICE_BUTTON" >> $TEMP_LAYOUT
        echo "disable DISABLE_SERVICE_BUTTON" >> $TEMP_LAYOUT
        echo "disable REMOVE_SERVICE_BUTTON" >> $TEMP_LAYOUT
    else
        echo "hide VITAL_WARNING_TEXT" >> $TEMP_LAYOUT
        echo "enable REMOVE_SERVICE_BUTTON" >> $TEMP_LAYOUT
    fi
    
    # Export changes to dialogbox
    cat "$TEMP_LAYOUT" >&$OUTPUTFD
rm -f -- "$TEMP_LAYOUT"
}

# Add unloaded services
load_service(){
    local SERVICE_NAME
    local LOADED_SERVICES
    local UNLOADED_SERVICES
    local U_SERVICE_CONTENT
    local SERVICE_BUTTONS
    
    LOADED_SERVICES="$(cat "$SERVICE_STATUS_LIST" | awk '{print $1}')"
    UNLOADED_SERVICES="$(echo "$ALL_SERVICES" | grep -vxf <(echo "$LOADED_SERVICES"))"
    # If no service to load, tell user
    if [[ -z "$UNLOADED_SERVICES" ]]; then
        # Format dialogbox elements
        U_SERVICE_CONTENT=$"All services are already loaded."
        U_SERVICE_CONTENT="add label \"${U_SERVICE_CONTENT}\" SERVICE_MESSAGE_TEXT"
    # Display a list of services the user wants to load
    else
        # Format UNLOADED_SERVICES for dialogbox (including icon)
        UNLOADED_SERVICES="$(echo "$UNLOADED_SERVICES" | awk -v icon="$SERVICE_UNUSED_ICON" '{print "add item " $0 " " icon}')"
        # Format dialogbox elements
        U_SERVICE_CONTENT="add listbox \"$SERVICES_TEXT\" LIST_SERVICES activation
            $UNLOADED_SERVICES
            end listbox LIST_SERVICES"
        SERVICE_BUTTONS="add frame horizontal
            add stretch
            add pushbutton \"${ADD_BUTTON_TEXT}\" ADD_SERVICE_PUSHBUTTON apply exit
            end frame"
    fi

    SERVICE_NAME=$(dialogbox --hidden -r <<ADDSERVICE
    $U_SERVICE_CONTENT
    $SERVICE_BUTTONS
    set stylesheet " QFrame {min-width:9em;}
                     QListWidget {icon-size:18px; text-align:left;
                      min-width:7em; min-height:6em; padding:3px}"
    set title "$ADD_SERVICE_TEXT"
    set icon "$MAIN_WINDOW_ICON"
    
    show
ADDSERVICE
)

    if [ $? -ne 0 ]; then
        SERVICE_NAME="$(echo "$SERVICE_NAME" | grep "^LIST_SERVICES=" | tail -n1 | cut -d"=" -f2)"
        if [[ ! -z "$SERVICE_NAME" ]] && [[ -d "${SERVICE_SOURCE}/${SERVICE_NAME}" ]]; then
            echo "$ADD_BUTTON_TEXT - $SERVICE_NAME"
            sudo ln -s "${SERVICE_SOURCE}/${SERVICE_NAME}" "${SERVICE_DIRECTORY}/${SERVICE_NAME}" 2>/dev/null
            SERVICE_SELECTED="$SERVICE_NAME"
            runit_force_rescan
            sudo sv status "$SERVICE_SELECTED" 1>/dev/null || sleep 1.5s
        fi
    fi
}

remove_service(){
    local SERVICE_NAME="${1}"
    
    if [[ ! -z "$SERVICE_NAME" ]] && [[ -e "${SERVICE_DIRECTORY}/${SERVICE_NAME}" ]]; then
        echo "$REMOVE_BUTTON_TEXT - $SERVICE_NAME"
        sudo rm "${SERVICE_DIRECTORY}/${SERVICE_NAME}"
    fi
}

# Modify service status
change_service_status(){
    local SERVICE_ACTION="${1}"
    local SERVICE_NAME="${2}"
    local OUTPUT_MESSAGE
    local SERVICE_PATH="$SERVICE_NAME"

    # If no service is selected, get out of here
    if [[ -z "$SERVICE_NAME" ]]; then return 1; fi

    # Prepare output message
    case $SERVICE_ACTION in
        service_*) OUTPUT_MESSAGE="$SERVICE_NAME - $SERVICE_TEXT";;
            log_*) OUTPUT_MESSAGE="$SERVICE_NAME - $LOG_TEXT"
                   SERVICE_PATH="${SERVICE_NAME}/log";;
    esac

    # perform correct action
    case $SERVICE_ACTION in
          *_start) echo "$OUTPUT_MESSAGE - $START_BUTTON_TEXT"
                   sudo sv start $SERVICE_PATH ;;
        *_restart) echo "$OUTPUT_MESSAGE - $RESTART_BUTTON_TEXT"
                   sudo sv restart $SERVICE_PATH ;;
           *_stop) echo "$OUTPUT_MESSAGE - $STOP_BUTTON_TEXT"
                   sudo sv stop $SERVICE_PATH ;;
         *_enable) echo "$OUTPUT_MESSAGE - $ENABLE_BUTTON_TEXT"
                   if [[ $(echo $SERVICE_PATH | grep -ic "/log") -gt 0 ]]; then
                    create_log "$SERVICE_NAME"
                   fi
                   if [[ -f "${SERVICE_DIRECTORY}/${SERVICE_PATH}/down" ]]; then
                    sudo rm "${SERVICE_DIRECTORY}/${SERVICE_PATH}/down"
                   fi
                   sudo sv start $SERVICE_PATH ;;
        *_disable) echo "$OUTPUT_MESSAGE - $DISABLE_BUTTON_TEXT"
                   if [[ $(echo $SERVICE_PATH | grep -ic "/log") -gt 0 ]]; then
                    create_log "$SERVICE_NAME"
                   fi
                   if [[ ! -f "${SERVICE_DIRECTORY}/${SERVICE_PATH}/down" ]]; then
                    sudo touch "${SERVICE_DIRECTORY}/${SERVICE_PATH}/down"
                   fi
                   sudo sv stop $SERVICE_PATH ;;
    esac
    
    # Recheck service status
    update_service_list && reload_service_listbox
}

create_log(){
    local RUNIT_SERVICE="${1}"
    
    # If log folder already exists, exit this function
    if [[ -d "${SERVICE_SOURCE}/${RUNIT_SERVICE}/log/" ]]; then return 1; fi

    mkdir "${SERVICE_SOURCE}/${RUNIT_SERVICE}/log/"
    cat << 'LOGTEMPLATE' > "${SERVICE_SOURCE}/${RUNIT_SERVICE}/log/run"
#!/bin/sh
set -e

NAME=template
LOG="/var/log/runit/$NAME"

test -d "$LOG" || mkdir "$LOG"
exec chpst svlogd -tt "$LOG"
LOGTEMPLATE

    sed -i "/^NAME=template/s/template/$RUNIT_SERVICE/" "${SERVICE_SOURCE}/${RUNIT_SERVICE}/log/run"
    chmod u+rwx,g+rx,o+rx "${SERVICE_SOURCE}/${RUNIT_SERVICE}/log/run"

    sudo touch "${SERVICE_SOURCE}/${RUNIT_SERVICE}/log/down"
}

#~ main

################################
###### STARTING DIALOGBOX ######
################################

coproc dialogbox --hidden -r
INPUTFD=${COPROC[0]}  # file descriptor the dialogbox process writes to
OUTPUTFD=${COPROC[1]}  # file descriptor the dialogbox process reads from
DBPID=$COPROC_PID    # PID of the dialogbox, if you need it for any purpose... e.g. to kill it

set -o monitor  # Enable SIGCHLD

# Create the dialogbox
cat >&$OUTPUTFD <<RUNITSERVICES
set stylesheet " QPushButton {icon-size:$ICON_SIZE; min-width:5em;}
                 QLabel {qproperty-alignment: AlignCenter;}
                 QTabWidget::tab-bar {alignment: center;}
                 QTabWidget::pane {border: 0px solid black; background: transparent;}"

add frame LEFT_FRAME vertical noframe
    add listbox "<b>${SERVICES_TEXT}</b>" SERVICE_LISTBOX selection
    end listbox SERVICE_LISTBOX
    add pushbutton "$ADD_BUTTON_TEXT" ADD_SERVICE_BUTTON
    add pushbutton "$REMOVE_BUTTON_TEXT" REMOVE_SERVICE_BUTTON
    add pushbutton "$RELOAD_BUTTON_TEXT" RELOAD_SERVICE_BUTTON
end frame
set LEFT_FRAME stylesheet " QFrame {min-width:9em; max-width:12em;}
                            QPushButton {icon-size:18px}
                            QListWidget {icon-size:18px; text-align:left;
                              min-width:7em; max-width:11em;
                              padding:3px; min-height:14em}"

                                   
step horizontal
add separator SEPARATOR_1 vertical
step horizontal
add frame TITLE_FRAME horizontal noframe
    add stretch
    add label "<big><big><b>service</b></big></big>" SERVICE_NAME_TEXT
    add stretch
end frame
set TITLE_FRAME stylesheet "QLabel {min-width: 10em}"
add label "$VITAL_WARNING_TEXT" VITAL_WARNING_TEXT
hide VITAL_WARNING_TEXT

add stretch
add label "<b>${SERVICE_TEXT}</b>" SERVICE_TEXT

add frame SERVICE_STATUS_FRAME horizontal
    add label "$STATUS_TEXT ?" SERVICE_STATUS_TEXT
    add stretch
    add pushbutton "$START_BUTTON_TEXT" START_SERVICE_BUTTON
    set START_SERVICE_BUTTON stylesheet "min-width:1em"
    add pushbutton "$RESTART_BUTTON_TEXT" RESTART_SERVICE_BUTTON
    set RESTART_SERVICE_BUTTON stylesheet "min-width:1em"
    add pushbutton "$STOP_BUTTON_TEXT" STOP_SERVICE_BUTTON
    set STOP_SERVICE_BUTTON stylesheet "min-width:1em"
    disable START_SERVICE_BUTTON
    disable STOP_SERVICE_BUTTON
end frame

add frame SERVICE_STARTUP_FRAME horizontal
    add label "$STARTUP_TEXT ?" SERVICE_STARTUP_TEXT
    add stretch
    add pushbutton "$ENABLE_BUTTON_TEXT" ENABLE_SERVICE_BUTTON
    set ENABLE_SERVICE_BUTTON stylesheet "min-width:1em"
    add pushbutton "$DISABLE_BUTTON_TEXT" DISABLE_SERVICE_BUTTON
    set DISABLE_SERVICE_BUTTON stylesheet "min-width:1em"
    disable ENABLE_SERVICE_BUTTON
    disable DISABLE_SERVICE_BUTTON
end frame

add stretch
add label "<b>${LOG_TEXT}</b>" SERVICE_TEXT

add frame LOG_STATUS_FRAME horizontal
    add label "$STATUS_TEXT ?" LOG_STATUS_TEXT
    add stretch
    add pushbutton "$START_BUTTON_TEXT" START_LOG_BUTTON
    set START_LOG_BUTTON stylesheet "min-width:1em"
    add pushbutton "$STOP_BUTTON_TEXT" STOP_LOG_BUTTON
    set STOP_LOG_BUTTON stylesheet "min-width:1em"
    disable START_LOG_BUTTON
    disable STOP_LOG_BUTTON
end frame

add frame LOG_STARTUP_FRAME horizontal
    add label "$STARTUP_TEXT ?" LOG_STARTUP_TEXT
    add stretch
    add pushbutton "$ENABLE_BUTTON_TEXT" ENABLE_LOG_BUTTON
    set ENABLE_LOG_BUTTON stylesheet "min-width:1em"
    add pushbutton "$DISABLE_BUTTON_TEXT" DISABLE_LOG_BUTTON
    set DISABLE_LOG_BUTTON stylesheet "min-width:1em"
    disable ENABLE_LOG_BUTTON
    disable DISABLE_LOG_BUTTON
end frame
add stretch

set title "$MAIN_WINDOW_TITLE"
set icon "$MAIN_WINDOW_ICON"

show
RUNITSERVICES

SERVICE_SELECTED=""
update_service_list && reload_service_listbox

while IFS=$'=' read key value; do
  #echo "Output: $key $value"
  case $key in
## LEFT FRAME ##
    SERVICE_LISTBOX)
        SERVICE_SELECTED="$value"; get_service_status "$value";;
    RELOAD_SERVICE_BUTTON)
        echo "Reload Service list"
        update_service_list && reload_service_listbox;;
    ADD_SERVICE_BUTTON)
        load_service
        update_service_list && reload_service_listbox;;
    REMOVE_SERVICE_BUTTON)
        remove_service "$SERVICE_SELECTED"
        update_service_list && reload_service_listbox;;
## SERVICE ACTIONS ##
    START_SERVICE_BUTTON)
        change_service_status "service_start" "$SERVICE_SELECTED" ;;
    RESTART_SERVICE_BUTTON)
        change_service_status "service_restart" "$SERVICE_SELECTED" ;;
    STOP_SERVICE_BUTTON)
        change_service_status "service_stop" "$SERVICE_SELECTED" ;;
    START_LOG_BUTTON)
        change_service_status "log_start" "$SERVICE_SELECTED" ;;
    STOP_LOG_BUTTON)
        change_service_status "log_stop" "$SERVICE_SELECTED" ;;
    ENABLE_SERVICE_BUTTON)
        change_service_status "service_enable" "$SERVICE_SELECTED" ;;
    DISABLE_SERVICE_BUTTON)
        change_service_status "service_disable" "$SERVICE_SELECTED" ;;
    ENABLE_LOG_BUTTON)
        change_service_status "log_enable" "$SERVICE_SELECTED" ;;
    DISABLE_LOG_BUTTON)
        change_service_status "log_disable" "$SERVICE_SELECTED" ;;
## LEFT FRAME BUTTONS ##
    
    esac
done <&$INPUTFD

set +o monitor  # Disable SIGCHLD
wait $DBPID    # Wait for the user to complete the dialog
