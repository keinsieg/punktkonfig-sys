#!/bin/sh

# 07/14/19 BobC All but the grow functionality copied from other wingrid programs.  
#          Requires x11-utils package for xwininfo now.

PROGNAME=${0##*/}
PROGVERSION="1.1"

# --------------------
# Help and Information
# --------------------

# When requested show information about script
if [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
cat << end-of-messageblock

$PROGNAME version $PROGVERSION
Places the active window into a predetermined position and size on screen.

Usage: 
   $PROGNAME

Options:
   -h, --help     Show this output

Summary:
   The screen is notionally divided into 4 rectangles in a 2x2 grid.
   Each window may occupy any 1, any 2 adjacent, or all 4 rectangles.
   A 5th rectangle of the same size can be created in the center.
   
   WinGrid can also grow, shrink, maximize or close the active window.

   Launching is normally done using the keyboard via a combined key press.
   The combination of keys are assigned by the system window manager and can 
   be reassigned if desired.  

   Optional configuration items are available in
   /home/USERNAME/.config/wingrid/wingrid.conf

   Requires:
      awk, wmctrl, xdpyinfo, yad, x11-utils

   See also:
      wingrid-bottom.sh
      wingrid-bottomleft.sh
      wingrid-bottomright.sh
      wingrid-center.sh
      wingrid-grow.sh
      wingrid-left.sh
      wingrid-right.sh
      wingrid-shrink.sh
      wingrid-top.sh
      wingrid-topleft.sh
      wingrid-topright.sh
      wingrid-maximize.sh
      wingrid-close.sh

end-of-messageblock
   exit 0
fi



# --------------------------
# User Configurable Settings
# --------------------------

# Location of the user configurable settings file
CONFIGFILE="$HOME/.config/wingrid/wingrid.conf"

# Obtain the user specifiable configuration
if [ -f $CONFIGFILE ]; then
   . $CONFIGFILE

   else

   # Display an error message and exit
   ERRMSG=" $CONFIGFILE \n Was not found \n\n Exiting..."
   YADBOX="--title="Wingrid" --image="error" --button="OK:1""
   [ "$DISPLAY" != "" ] && yad $YADBOX --text="$ERRMSG"
   exit 1
fi

# Guard against missing individual settings 
[ "$WINHEIGHT_LESS" = "" ] && WINHEIGHT_LESS=0
[ "$WINHEIGHT_MORE" = "" ] && WINHEIGHT_MORE=0
[ "$GAPTOP" = "" ] && GAPTOP=0
[ "$GAPLEFT" = "" ] && GAPLEFT=0



# --------------------
# Construct Parameters
# --------------------

# Capture screen resolution value
SCREENRES=$(xdpyinfo | awk '/dimensions:/ { sub("x", " "); print $2" "$3 }')

# Extract screen resolution into height and width components
SCREENWIDTH=${SCREENRES% *}
SCREENHEIGHT=${SCREENRES#* }

# Calculate 50% of the screen width and height values
SCREENHALFWIDTH=$(($SCREENWIDTH/2))
SCREENHALFHEIGHT=$(($SCREENHEIGHT/2))

# Reference used by window manager when positioning the window (always zero)
GRAVITY=0

# Distance from screen top edge to top edge of top window
OFFSETTOP=$GAPTOP

# Distance from screen left edge to left edge of left window
OFFSETLEFT=$GAPLEFT

# Current Position and Dimensions of window
WINID=$(xdotool getactivewindow)
eval $(xwininfo -id "$WINID" |
      sed -n -e "s/^ \+Absolute upper-left X: \+\([0-9]\+\).*/WCURPOSX=\1/p" \
             -e "s/^ \+Absolute upper-left Y: \+\([0-9]\+\).*/WCURPOSY=\1/p" \
             -e "s/^ \+Width: \+\([0-9]\+\).*/WINWIDTH=\1/p" \
             -e "s/^ \+Height: \+\([0-9]\+\).*/WINHEIGHT=\1/p" )

# current
echo "wingrid-grow starting info"
echo "Grav,XPos,YPos,Xwide,Xhigh g=$GRAVITY xp=$WCURPOSX yp=$WCURPOSY xw=$WINWIDTH yh=$WINHEIGHT"
             
# total available screen size
NETSCREENWIDTH=$(($SCREENWIDTH-$OFFSETLEFT))
NETSCREENHEIGHT=$(($SCREENHEIGHT-($OFFSETTOP+$WINHEIGHT_MORE)))

# growth divisor 8 = grow 1/8 of avail space on each side, each time if possible
#    lower numbers will grow faster, like taking the red pill :)               
GROWDIV=8

# grow window logic
# grow by 1/GROWDIV of remaining area on each side, limited to min and max screen coordinates
# x axis
AVAILX=$(($NETSCREENWIDTH-$WINWIDTH))
# if any room, grow window wider
if [ "$AVAILX" -gt "0" ]
then
   CHGSIZX=$(($NETSCREENWIDTH/$GROWDIV))
   WCURPOSX=$(($WCURPOSX-$CHGSIZX))
   WINWIDTH=$(($WINWIDTH+$CHGSIZX))
   # if not enough room to left, limit and grow more to right if possible
   if [ "$WCURPOSX" -le "$OFFSETLEFT" ]
   then
      CHGSIZX=$(($OFFSETLEFT-$WCURPOSX))
      WINWIDTH=$(($WINWIDTH+$CHGSIZX))
      WCURPOSX=$OFFSETLEFT
   fi
   # limit grow to right
   if [ "$WINWIDTH" -gt "$NETSCREENWIDTH" ]
   then
      WINWIDTH=$NETSCREENWIDTH
   fi
fi
# y axis
AVAILY=$(($NETSCREENHEIGHT-$WINHEIGHT))
# if any room, grow window taller
if [ "$AVAILY" -gt "0" ]
then
   CHGSIZY=$(($NETSCREENHEIGHT/$GROWDIV))
   WCURPOSY=$(($WCURPOSY-$CHGSIZY))
   WINHEIGHT=$(($WINHEIGHT+$CHGSIZY))
   # if not enough room above, limit and grow more below if possible
   if [ "$WCURPOSY" -le "$OFFSETTOP" ]
   then
      CHGSIZY=$(($OFFSETTOP-$WCURPOSY))
      WINHEIGHT=$(($WINHEIGHT+$CHGSIZY))
      WCURPOSY=$OFFSETTOP
   fi
   # limit grow below
   if [ "$WINHEIGHT" -gt "$NETSCREENHEIGHT" ]
   then
      WINHEIGHT=$NETSCREENHEIGHT
   fi
fi

echo "wingrid-grow results"
echo "Grav,XPos,YPos,Xwide,Xhigh g=$GRAVITY xp=$WCURPOSX yp=$WCURPOSY xw=$WINWIDTH yh=$WINHEIGHT"

# ----------------------------
# Put Window into Grid Pattern
# ----------------------------

# Ensure the active window is not in maximized mode nor in fullscreen mode
wmctrl -r :ACTIVE: -b remove,maximized_horz,maximized_vert
wmctrl -r :ACTIVE: -b remove,fullscreen

# Position and resize the active window 
wmctrl -r :ACTIVE: -e $GRAVITY,$WCURPOSX,$WCURPOSY,$WINWIDTH,$WINHEIGHT
