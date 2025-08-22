#!/bin/sh


# Select an app to open a file highlighted in ROX-Filer


# Path to ROX-Filer's Send To directory
SENDTODIR=~/.config/rox.sourceforge.net/SendTo


# Path to the file offering guidance to the user
GUIDE=/tmp/open-with-guide.txt


# Obtain the mimetype of the highlighted file
MIMETYPE=$(rox -m "$@")


# Transform the mimetype to the hidden dir-name-type expected by ROX-Filer's Send To feature
DIRNAMETYPE=.$(echo "$MIMETYPE" | sed 's/\//_/g')


# Ensure a directory is available for the type of file selected
if [ ! -d "$SENDTODIR"/$DIRNAMETYPE ]; then
   mkdir "$SENDTODIR"/$DIRNAMETYPE
fi


# Ensure a guidance file is available
cat << end-of-guideblock > $GUIDE

   Open With Menu Guide


   Purpose
   Add one or more apps to the ROX-Filer right-click menu via drag-and-drop.

   
   Summary
   In ROX-Filer, right-clicking on a file displays a pop-up menu. At the head of the 
   menu is an area that shows apps added by you, the user.  Choosing one of 
   these apps opens it with the selected file. 

   The apps displayed in this pop-up menu change depending upon the type of file
   you right-clicked on.  Only apps that work with the type of file selected are
   displayed.

   It is possible to have multiple apps in the menu that will work on a single 
   type of file.  For example, if your photos are jpeg type files, you might have 
   an app to view image files and a different app to edit them.


   Example
   Add two apps that can open a file named filename.jpeg

   1. Highlight a jpeg file in ROX-Filer
   2. Right-Click-->Send To-->Open With Menu
   3. Drag-and-drop mirage.desktop (a viewer) and mtpaint.desktop (an editor)
          from the window named /usr/share/applications
          to the window named ~/.config.sourceforge.net/SendTo/.image_jpeg
   4. Choose Link (relative) when prompted
   5. On the mirage.desktop link, right-click-->Rename 
   6. Rename mirage.desktop to Open With Mirage
   7. Repeat renaming mtpaint.desktop to Open With mtPaint

   A right-click on a jpeg or jpg file will display both apps at the head of the pop-up menu.


   Apps can also be removed from the pop-up menu.

   Example
   Remove "Open With mtPaint" for jpeg type files

   1. Highlight a jpeg file in ROX-Filer
   2. Right-Click-->Send To-->Open With Menu
   3. In the window named ~/.config.sourceforge.net/SendTo/.image_jpeg
           Delete "Open with mtPaint"

end-of-guideblock


# Display the guidance file
dillo $GUIDE &


# Open a window in the hidden directory and display the guidance
rox -d "$SENDTODIR"/$DIRNAMETYPE/ &


# Open a window showing the apps installed
rox -d /usr/share/applications &


exit
