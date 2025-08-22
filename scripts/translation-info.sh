#!/bin/bash
# antiX translation-info ver. 0.8
# 2021 by Robin (antiX community)
# GPL v.3
# Tiny script to display a message informing user in case the language
# he selected from boot menu was not completely translated and he bumps
# unexpectedly on an English desktop instead.
 
TEXTDOMAINDIR=/usr/share/locale
TEXTDOMAIN=translation-info.sh

# Configurable settings --------------------------------------------------------------------------------------------------------
tray_icon="/usr/share/icons/Adwaita/24x24/actions/go-home.png"			# set some nice tray icon existing in next ISO here to avoid yad erlenmayer flask.
nointernet_icon="/usr/share/icons/Adwaita/24x24/status/network-error.png" # set some nice tray icon existing in next ISO here
langselect_icon="/usr/share/icons/Adwaita/24x24/emblems/emblem-web.png"	# set some nice tray icon existing in next ISO here
export settingsfile="$HOME/.config/translation-info.conf"		# path to this file is used to remove its STARTUP_DIALOG_CMD entry from this file.
infofile_path="/usr/share/locale-antix/docs"							# set location where advanced pdf info files are stored, e.g. $HOME/.antiX-translation-info
infofile_1="antiX-translation-info.pdf"									# infofile to be opened when clicking the button »more information«
infofile_2="antiX-transifex-info.pdf"									# infofile to be opened if no internet connection to transifex could be established while user clicked on one of the links.
export online_resource_1="https://www.transifex.com/anticapitalista"						# 1st internet address to open when user clicks the respectively labled text button
export online_resource_2="https://www.transifex.com/antix-linux-community-contributions"	# 2nd internet address to open when user clicks the respectively labled text button
blocklist="fr,en,de,pt_PT" # blocklist string, comma separated: add or remove what is considered to be necessary while creating a new antiX ISO version, depending
						# of current state of translation of a specific language or language group. Two/Three character language identifiers (e.g. »en« or »fil«)
						# as well as four significant character language identifiers (e.g. »en_GB«) are accepted, but please note that any two character
						# language identifier will blocklist the complete language group, which comprises all flavours of this language group at once.
						# (e.g. »en« will blocklist »en_GB«, »en_US«, »en_CA«, »en_AU«, »en_IE«, »en_NZ« ... and exclude them from message display.)
export check_alive_ip="8.8.8.8 443"  # set a reliable default ip server address+port for online connection check.
preferred_pdf="mupdf"	# set preferred pdf application to display info files. If omitted, xdg-open will be used instead
# ------------------------------------------------------------------------------------------------------------------------------

# Exit script if STARTUP_DIALOG_CMD is "no"
if [ -r "$settingsfile" ]; then
    . "$settingsfile"
    [ "$STARTUP_DIALOG_CMD" = "no" ] && exit 0
fi

# determine whether blocklist is to be respected or ignored
ignore_blocklist=false
if [ "$1" == "--ignore-blocklist" ] || [ "$1" == "-i" ]; then ignore_blocklist=true; fi

# display usage help message on console if requested
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
echo -e "\n  "$"translation-info""\n\n  "$"This script displays an  informational dialog window on user interfaces""\n  "$"of any language not blocklisted after startup, informing user about the""\n  "\
$"fact  antiX was not completely or not at all translated to the language""\n  "$"he has  chosen from  boot menu,  causing him  to face  English language""\n  "$"instead nevertheless.""\n\n  "$"Command line options:""\n\n  "\
"--ignore-blocklist"" "$"or"" -i"" . . . . . "$"Allow execution even on blocklisted""\n                                    "$" languages of user interface.""\n  ""--help "$"or"" -h"" . . . . . . . . . . . "\
$"Display this help message.""\n\n  "$"Questions, suggestions and bug reporting please to:""\n\n\t<forum.antiXlinux.com>\n"
# entry needed to comply with EU legislation. This GPL text may not get translated. See gnu.org for details.
echo -e "  Copyright 2021 the antiX comunity\n\n  This program is free software: you can redistribute it and/or modify\n  it under the terms of the GNU General Public License as published by\n  "\
"the  Free Software Foundation, either  version 3  of the License, or\n  (at your option) any later version.\n\n  This program is distributed in the hope that it will be useful,\n  "\
"but  WITHOUT ANY WARRANTY; without even the implied warranty of\n  MERCHANTABILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the\n  GNU General Public License for more details.\n\n  "\
"You should have received a copy of the GNU General Public\n  License along with this program.  If not, see\n\n\t<http://www.gnu.org/licenses/>.\n"
fi

# get active user interface language
MY_LANGUAGE="${LANGUAGE:-${LANG}}"
ui_lang_4="$(echo $MY_LANGUAGE | cut -d. -f1)"
ui_lang_2="$(echo $MY_LANGUAGE | cut -d_ -f1)"

# Skip any action and exit if language or language group is blocklisted
if [ "$(echo "$blocklist" | grep -E "(^$ui_lang_4,|,$ui_lang_4,|,$ui_lang_4$|^$ui_lang_2,|,$ui_lang_2,|,$ui_lang_2$)")" != "" ] && ! $ignore_blocklist; then exit 0; fi

# Create tempfiles for gtkdialog workaround
export tempfile_01="/tmp/antiX-translation-info-$$01.tmp"
export tempfile_02="/tmp/antiX-translation-info-$$02.tmp"

# create recent list of supported languages from debian resource file
export language_list="|$(cat /usr/share/i18n/SUPPORTED | cut -d. -f1 | cut -d' ' -f1 | sort -u | sed 's/'$ui_lang_4'$/^'$ui_lang_4'/' | tr '\n' '|' | rev | cut -c 2- | rev)"

# match program to open pdf files
if [ "$(echo "$infofile_1" | rev | cut -d. -f1)" == "fdp" ] && which "$preferred_pdf" >/dev/null; then export file_opener_1="$preferred_pdf"; else export file_opener_1="xdg-open"; fi
if [ "$(echo "$infofile_2" | rev | cut -d. -f1)" == "fdp" ] && which "$preferred_pdf" >/dev/null; then export file_opener_2="$preferred_pdf"; else export file_opener_2="xdg-open"; fi

# check whether exists a localised version of info file
if [ -e "$(echo "$infofile_path/$infofile_1" |sed "s/\(.*\)\.\(.*\)/\1.$ui_lang_4.\2/")" ]; then
	export info_file="$(echo "$infofile_path/$infofile_1" |sed "s/\(.*\)\.\(.*\)/\1.$ui_lang_4.\2/")"
elif [ -e "$(echo "$infofile_path/$infofile_1" |sed "s/\(.*\)\.\(.*\)/\1.$ui_lang_2.\2/")" ]; then
	export info_file="$(echo "$infofile_path/$infofile_1" |sed "s/\(.*\)\.\(.*\)/\1.$ui_lang_2.\2/")"
else
	export info_file="$infofile_path/$infofile_1"
fi

# function no_internet {...}
# Workaround for nonfunctional exported functions in gtkdialog action tags
# Write function in tempfile instead of exporting it
cat <<<'#!/bin/bash
yad --undecorated --fixed --borders=10 \
		--window-icon="'$nointernet_icon'" \
		--title="'$"Connection error"'" \
		--text="'"<b><u>"$"No internet connection available.""</u></b>\n\n"$"Click »Procede« after having established the connection.""\n\t"$"Alternatively you may view some local information""\n\t"$"instead by pressing the respective button.""\n"'" \
	    --button="'$"Display local Information"'":3 --button="'$"Procede"'":5 --button="'$"Cancel"'":7
buttonselect=$?
if [ $buttonselect == 3 ]; then # show local information
	$('$file_opener_2' "'$infofile_path/$infofile_2'")
elif [ $buttonselect == 5 ]; then # procede opening requested url in browser
	xdg-open "$1"
# elif [ $buttonselect == 7 ]; then # Cancel this request
#	echo "request cancelled by user"
fi
' > "$tempfile_01"
chmod 755 "$tempfile_01"

# function language_select {...}
# Workaround for nonfunctional exported functions in gtkdialog action tags
# Write function in tempfile instead of exporting it
cat <<<'#!/bin/bash
selected_language="$(yad --undecorated --fixed --height=200 --center --borders=10 \
		--window-icon="'$langselect_icon'" \
		--title="'$"Language selection"'" \
		--text="'"<b>"$"Language selection""</b>\n\n"$"Please select the language in which""\n"$"you d like to read this information""\n"$"from the pulldown menu."'" \
		--form \
		--item-separator="|" \
		--field="'$"Available languages:"'":CB \
		"$language_list" \
		--button="'$"Apply"'":4 --button="'$"Cancel"'":5)"
buttonselect=$?

selected_language="$(echo "$selected_language" | tr -d "|").UTF8"

if [ $buttonselect == 4 ]; then # reload info message in user selected language
	LANG="$selected_language" setsid /bin/bash translation-info.sh --ignore-blocklist & exit 0
elif [ $buttonselect == 5 ]; then # Cancel this request
	setsid /bin/bash translation-info.sh --ignore-blocklist & exit 0
fi
' > "$tempfile_02"
chmod 755 "$tempfile_02"

# display translation info
export MAIN_DIALOG='
<window title="'$"Language information"'" decorated="false" window_position="1" skip_taskbar_hint="true" resizable="false">
		<vbox>
			<text xalign="0" selectable="true" use-markup="true">
				<label>"<small><small><small><small><small> </small></small></small></small></small>"</label>
			</text>
			<hbox>
			<text xalign="0" selectable="true" use-markup="true">
				<label>"<span foreground='"'red'"'>    <big><big><big><b>'$"Do you see English only?"'</b></big></big></big>                </span>"</label>
			</text>
				<button>
					<label>"  '$"Select Language"'  "</label>
					<action>/bin/bash $tempfile_02 &</action>
					<action type="exit">Exit</action>
				</button>
			</hbox>
			<text xalign="0" use-markup="true">
				<label>"<small><small><small> </small></small></small>"</label>
			</text>
			<text xalign="0" selectable="true" use-markup="true">
				<label>"    '$"antiX is not translated to your favourite language yet?"'"</label>
			</text>
			<text xalign="0" selectable="true" use-markup="true">
				<label>"    '$"Are you facing untranslated parts?"'"</label>
			</text>
			<text xalign="0" use-markup="true">
				<label>"<small> </small>"</label>
			</text>
			<text selectable="true" use-markup="true">
				<label>"<span foreground='"'red'"'>                <big><b>'$"This can be helped."'</b></big></span>"</label>
			</text>
			<text xalign="0" use-markup="true">
				<label>"<small> </small>"</label>
			</text>
			<text xalign="0" wrap="false" selectable="true" use-markup="true">
				<label>"    '$"In case you understand apart from your native tongue"'"</label>
			</text>
			<text xalign="0" wrap="false" selectable="true" use-markup="true">
				<label>"    '$"a bit of English also, you can contribute a bit, so you can"'"</label>
			</text>
			<text xalign="0" wrap="false" selectable="true" use-markup="true">
				<label>"    <u>'$"experience antiX in your own tongue soon."'</u>"</label>
			</text>
			<text xalign="0" wrap="false" selectable="true" use-markup="true">
				<label>"    <b>'$"Join antiX translation team of volunteers,"'</b>"</label>
			</text> 
			<text xalign="0" wrap="false" selectable="true" use-markup="true"> 
				<label>"    '$"you are always welcome to take part in the translations."'"</label>
			</text> 
			<text xalign="0" wrap="false" selectable="true" use-markup="true"> 
				<label>"    '$"It is not difficult, and you can do as much or little as you like."'"</label>
			</text>
			<text xalign="1" wrap="false" selectable="true" use-markup="true"> 
				<label>"<span foreground='"'red'"'><b>'$"Just do it."'          </b></span>"</label>
			</text>
			<text xalign="0" selectable="true" use-markup="true">
				<label>"<small><small><small><small><small><small><small> </small></small></small></small></small></small></small>"</label>
			</text>
			<text xalign="0" use-markup="true">
				<label>"    <u>'$"Sign up for free:"'</u>"</label>
			</text>
		<hbox>
			<button relief="2">
				<label>"  '$online_resource_1'                                                          "</label>
				<action>if nc -zw1 $check_alive_ip; then xdg-open "$online_resource_1"; else /bin/bash $tempfile_01 "$online_resource_1"; fi</action>
			</button>
		</hbox>
		<hbox>
			<button relief="2">
				<label>"  '$online_resource_2'        "</label>
				<action>if nc -zw1 $check_alive_ip; then xdg-open "$online_resource_2"; else /bin/bash $tempfile_01 "$online_resource_2"; fi</action>
			</button>
			<text xalign="0" use-markup="true">
				<label>"<small> </small>"</label>
			</text>
		</hbox>
		<hbox>
			<button>
				<label>"  '$"More Information"'  "</label>
				<action>$($file_opener_1 "$info_file")</action>
			</button>
			<button>
				<label>"  '$"Don't show again"'  "</label>
				<variable>BUTTON_2</variable>
				<action>echo "STARTUP_DIALOG_CMD=no" > "$settingsfile"</action>
				<action type="disable">BUTTON_2</action>
			</button>
			<button>
				<label>"  '$"Close"'  "</label>
				<action type="exit">Exit</action>
			</button>
		</hbox>
	</vbox>
</window>
'
gtkdialog --program=MAIN_DIALOG >/dev/null

# cleanup
[ -e "$tempfile_01" ] && rm -f "$tempfile_01"
[ -e "$tempfile_02" ] && rm -f "$tempfile_02"

exit 0
