#!/bin/sh


# As root edit a text file highlighted in ROX-Filer


# Specify your preferred text editor
EDITOR=leafpad

# Specify your preferred way to run as root 
ASROOT=gksu 

# Request the password, if valid open the file to be edited
exec $ASROOT $EDITOR "$@"
