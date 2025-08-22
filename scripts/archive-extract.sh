#!/bin/sh


# Extract the contents of an archive highlighted in ROX-Filer 


# Specify your preferred archiver
ARCHIVER=file-roller
#ARCHIVER=xarchiver

# Open the archive and ask for the destination folder
exec $ARCHIVER --extract "$@"
