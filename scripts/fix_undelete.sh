#!/bin/bash
#Mini script to decode special characters from the trash-cli generated files that store info about where to "undelete" files
#function to decode characters
urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

#Create and make sure the temporary file is empty
touch /tmp/undeletefiledata
echo "" > /tmp/undeletefiledata

#file to convert:
#file="/home/demo/.local/share/Trash/info/caão.trashinfo"
 file=$(echo "$1")

#read the original file's undelete info and output it all to the temporary file (so zzzfm's Restore script works even on fodlers/files names with special characters)
while read line; do  correctedline=$(urldecode "$line"); echo $correctedline >> /tmp/undeletefiledata; done < "$file"

#For debbuging only, display converted file
#cat "/tmp/undeletefiledata"

#replace original file with restore info with a decoded one:
mv "/tmp/undeletefiledata" "$1"


