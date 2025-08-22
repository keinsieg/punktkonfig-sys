#!/bin/bash
#Date and Time Setting Tool Copyright 2009,2011 by Tony Brijeski under the GPL V2
# modified by skidoo and ppc -Jul 31st, 2019 - https://pastebin.com/1YmJHb95

## Translatable strings ##
TEXTDOMAINDIR=/usr/share/locale
TEXTDOMAIN=set_time-and_date

TITLETEXT=$"Manage Date and Time Settings"
testroot="`whoami`"   #  howdy       backticks galore
DATE_TEXT=$"Date:"
SETTIME_TEXT=$"Set Current Time"
SETDATE_TEXT=$"Set Current Date"
SETTZ_TEXT=$"Choose Time Zone (using cursor and enter keys)"
SETAUTO_TEXT=$"Use Internet Time server to set automaticaly time/date"
SETLOCAL_TEXT=$"Set system clock time scale to LOCAL"
SETUTC_TEXT=$"Set system clock time scale to UTC"
SETHOUR_TEXT=$"Move the slider to the correct Hour"
SETMINUTE_TEXT=$"Move the slider to the correct Minute"
SETTIMEZONE_TEXT=$"Select Time Zone"
EXIT_TEXT=$"Quit"
WARNING1_TEXT=$"Warning: dpkg-reconfigure is not installed. \n Please install it and try again"
WARNING2_TEXT=$"Warning: /usr/share/zoneinfo directory does not exist."

## YAD GUI - section by section ##
DIALOG="`which yad` --width 550 --center --undecorated --window-icon=time"
TITLE="--always-print-result --dialog-sep --title="
TEXT="--text="
ENTRY="--entry "
ENTRYTEXT="--entry-text "
MENU="--list --print-column=1 --column=Pick:HD --column=_"
YESNO="--question "
MSGBOX="--info "
SCALE="--scale "
PASSWORD="--entry --hide-text "

## MAIN SCRIPT ##
 
if [ "$testroot" != "root" ]; then
    gksu $0
    exit 1
fi
 
while [ "$SETCHOICE" != "Exit" ]; do
 DAY="`date +%d`"
 MONTH="`date +%m`"
 YEAR="`date +%Y`"
 MINUTE="`date +%M`"
 HOUR="`date +%H`"
 SETCHOICE=`$DIALOG --no-buttons --height 300 $TITLE"$TITLETEXT" $MENU --text=" $TITLETEXT \n\n $DATE_TEXT $(date)\n" SETTIME " $SETTIME_TEXT" SETDATE " $SETDATE_TEXT"  SETTZ " $SETTZ_TEXT"  SETAUTO " $SETAUTO_TEXT" SETLOCAL " $SETLOCAL_TEXT" SETUTC " $SETUTC_TEXT" Exit " $EXIT_TEXT"`
 SETCHOICE=`echo $SETCHOICE | cut -d "|" -f 1`
 
 if [ "$SETCHOICE" = "SETTIME" ]; then
    HOUR="`date +%H`"
    HOUR=`echo $HOUR | sed -e 's/^0//g'`
    SETHOUR=`$DIALOG $TITLE"$TITLETEXT" $SCALE --value=$HOUR --min-value=0 --max-value=23 $TEXT"$SETHOUR_TEXT"`
    if [ "$?" = "0" ]; then
        if [ "${#SETHOUR}" = "1" ]; then
            SETHOUR="0$SETHOUR"
        fi
 
        MINUTE="`date +%M`"
        MINUTE=`echo $MINUTE | sed -e 's/^0//g'`
    fi
 
    SETMINUTE=`$DIALOG $TITLE"$TITLETEXT" $SCALE --value=$MINUTE --min-value=0 --max-value=59 $TEXT"$SETMINUTE_TEXT"`
    if [ "$?" = "0" ]; then
        if [ "${#SETMINUTE}" = "1" ]; then
            SETMINUTE="0$SETMINUTE"
        fi
 
        date $MONTH$DAY$SETHOUR$SETMINUTE$YEAR
        hwclock --systohc
    fi
 fi
 
 if [ "$SETCHOICE" = "SETDATE" ]; then
    var=$(yad --window-icon=time --calendar --undecorated --center --date-format="%Y%m%d")

	SETYEAR=$(echo ${var:0:4})
	SETMONTH=$(echo ${var:4:2})
	SETDAY=$(echo ${var:6:2})
	MINUTE="`date +%M`"
	HOUR="`date +%H`"
	sudo date $SETMONTH$SETDAY$HOUR$MINUTE$SETYEAR
                hwclock --systohc
 fi
 
 if [ "$SETCHOICE" = "SETAUTO" ]; then
	sudo date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"
                hwclock --systohc
 fi
 
 if [ "$SETCHOICE" = "SETTZ" ]; then
	# Check if dpkg-reconfigure is available
	if ! command -v dpkg-reconfigure &> /dev/null; then
		yad --center --text="$WARNING1_TEXT" --no-buttons --window-icon=time
		exit
	fi
	# Check if /usr/share/zoneinfo directory exists	
	if [ ! -d "/usr/share/zoneinfo" ]; then
		yad --center --text="$WARNING2_TEXT" --no-buttons --window-icon=time
		exit
	fi

	sudo roxterm --hide-menubar -z 0.75 -T " $SETTIMEZONE_TEXT" -e /bin/bash -c "dpkg-reconfigure tzdata"
 fi

 if [ "$SETCHOICE" = "SETLOCAL" ]; then
	sudo hwclock --systohc --localtime
 fi

 if [ "$SETCHOICE" = "SETUTC" ]; then
	sudo hwclock --systohc --utc
 fi

done
 
exit 0
