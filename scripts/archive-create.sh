#!/bin/sh


# Archive the files and directories highlighted in ROX-Filer


# Specify your preferred archiver
ARCHIVER=file-roller
#ARCHIVER=xarchiver

# Create the archive
exec $ARCHIVER -d "$@"
