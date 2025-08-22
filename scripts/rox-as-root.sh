#!/bin/sh


# Open a ROX-Filer window as root from the menu of ROX-Filer as an unprivileged user.
# The root window opens at the same location as a single item highlighted in ROX-Filer as user.


# Obtain the location of the highlighted item
DIR=$(dirname "$@")

# Specify the preferred way to run as root 
ASROOT=sudo

# Start ROX-Filer as root at the specified location
$ASROOT rox -d "$DIR"
