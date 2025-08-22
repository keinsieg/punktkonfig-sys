#!/bin/sh


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
      awk, wmctrl, xdpyinfo, yad

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
echo "wingrid-shrink starting info"
echo "Grav,XPos,YPos,Xwide,Xhigh g=$GRAVITY xp=$WCURPOSX yp=$WCURPOSY xw=$WINWIDTH yh=$WINHEIGHT"
             
# total available screen size
NETSCREENWIDTH=$(($SCREENWIDTH-$OFFSETLEFT))
NETSCREENHEIGHT=$(($SCREENHEIGHT-($OFFSETTOP+$WINHEIGHT_MORE)))

# shrink divisor 10 = shrink 1/10 of avail space on each side, each time if possible
#    lower numbers will shrink faster, like taking the blue pill :)               
SHRINKDIV=-10

# shrink window logic
# resulting window must be at least larger than one shrink step worth
# x axis
CHGSIZX=$(($NETSCREENWIDTH/$SHRINKDIV))
TESTWIDTH=$(($WINWIDTH+($CHGSIZX*3)))
# if big enough, shrink one step
if [ "$TESTWIDTH" -gt "0" ]
then
   WINWIDTH=$(($WINWIDTH+($CHGSIZX*2)))
fi
echo "ChangeX, NetScreenwidth, TestWidth, winwidth c=$CHGSIZX ns=$NETSCREENWIDTH tw=$TESTWIDTH xw=$WINWIDTH"
# y axis
CHGSIZY=$(($NETSCREENHEIGHT/$SHRINKDIV))
TESTHEIGHT=$(($WINHEIGHT+($CHGSIZY*3)))
# if big enough, shrink one step
if [ "$TESTHEIGHT" -gt "0" ]
then
   WINHEIGHT=$(($WINHEIGHT+($CHGSIZY*2)))
fi
echo "ChangeY, NetScreenHeight, TestHeight, winheight c=$CHGSIZY ns=$NETSCREENHEIGHT nw=$TESTHEIGHT xw=$WINHEIGHT"

echo "wingrid-shrink results"
echo "Grav,XPos,YPos,Xwide,Xhigh g=$GRAVITY xp=$WCURPOSX yp=$WCURPOSY xw=$WINWIDTH yh=$WINHEIGHT"

# ----------------------------
# Put Window into Grid Pattern
# ----------------------------

# Ensure the active window is not in maximized mode nor in fullscreen mode
wmctrl -r :ACTIVE: -b remove,maximized_horz,maximized_vert
wmctrl -r :ACTIVE: -b remove,fullscreen

# Position and resize the active window 
wmctrl -r :ACTIVE: -e $GRAVITY,$WCURPOSX,$WCURPOSY,$WINWIDTH,$WINHEIGHT
