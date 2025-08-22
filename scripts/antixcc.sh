#!/bin/bash
# -*- coding: utf-8 -*-
# please use "xgettext --from-code=UTF-8 -L shell -o antixcc-new.pot antixcc.sh" command to extract the translatable strings.
# please make sure to apply "msgmerge antixcc.pot -U antixcc-new.pot" to keep the developers notes for translators.
#
# File Name: controlcenter.sh
# Purpose: all-in-one control centre for antiX
# Authors: OU812 and minor modifications by anticapitalista
# Latest Change:
# 20 August 2008
# 11 January 2009 and renamed antixcc.sh
# 15 August 2009 some apps and labels altered.
# 09 March 2012 by anticapitalista. Added Live section.
# 22 March 2012 by anticapitalista. Added jwm config options and edited admin options.
# 18 April 2012 by anticapitalista. mountbox-antix opens as user not root.
# 06 October 2012 by anticapitalista. Function for ICONS. New icon theme.
# 26 October 2012 by anticapitalista. Includes gksudo and ktsuss.
# 12 May 2013 by anticapitalista. Let user set default apps.
# 05 March 2015 by BitJam: Add alsa-set-card, edit excludes, edit bootloader.  Fix indentation.
#   * Hide live tab on non-live systems.  Use echo instead of gettext.
#   * Remove unneeded doublequotes between tags.  Use $(...) instead of `...`.
# 01 May 2016 by anticapitalista: Use 1 script and use hides if nor present on antiX-base
# 11 July 2017 by BitJam:
#   * use a subroutine to greatly consolidate code
#   * use existence of executable as the key instead of documentation directory
#     perhaps I should switch to "which" or "type"
#   * move set-dpi to desktop tab
#   * enable ati driver button in hardware tab
# 18 Nov by antiX-Dave: fix edit jwm settings button to match icons with icewm and fluxbox
# 22 May 2023 by Robin-antiX: Add tooltips, add SCSI bus rescan tool; fix window header translatable; add block to prevent multiple parallel instances of acc.
# 25 Dec 2023 by Robin-antiX: Fix for equaliser entry not displayed due to .desktop file is not found by test -x; Modified equalizer_entry setup to provide either
#    ALSA equaliser or an Pipewire compatible equaliser depending whether user runs plain ALSA or additionally Pipewire sound server (in the latter case ALSA
#    equaliser doesn't have any effect on audio when it's sliders are moved until Pipewire is shut down).
# 07 Jan 2024 by Robin-antiX: Moved installer subroutine present in several entries to a subroutine so it can be used from all entries whenever it is needed to add some prerequisites. 
# 25 Jan 2024 by Robin-antiX: Added functions for adding/removing antiX startup file entries. Improved plain ALSA ./. pipewire sound server layer logic.
#    Some additional fixes. Added clipit switch incluing taking care for startup file. Merged divergent (silently changed) translatable strings from
#    antiX 23 iso version of script to original version, containing utf8 style quoting within strings, present at the git repo, to match the likewise
#    (silently) replaced transifex source template .pot
# 01 Feb 2024 by Robin-antiX: Added autosuspend entry. +Fix for startup entries containing slashes or ampersand. Improved startup file management. Sorted hardware tab.
# 05 Feb 2024 by anticapitalista. fixed typos, added Shared Folders,  added antiX cloud, added Language, put suspend-grey icon in /usr/share/pixmaps/papirus
# 26 Feb 2024 by Robin fix for user closing installer window prematurely by X in window border; added multilingual keyboard 4 level layout map
# 13/28 Jul 2024 by Robin added compositor toggle, disk usage analyser
# 08 Jul 2025 by Robin added hostname changer, memory manager.
#
# Acknowledgements: Original script by KDulcimer of TinyMe. http://tinyme.mypclinuxos.com
#################################################################################################################################################

version=1.2.8

TEXTDOMAINDIR=/usr/share/locale
TEXTDOMAIN=antixcc

if [ "$(wmctrl -l | sed -n 's/^\(..*\)  ..* '$"antiX Control Centre"'/\1/p')" != "" ]; then
  wmctrl -F -a $"antiX Control Centre"
  exit 0
fi

# Options

#antix-faenza=faenza icons used on antiX-17.4
#antix-moka=moka icons used on earlier releases
#antix-papirus=papirus converted to png icons
#antix-numix-bevel=numix-bevel png icons
#antix-numix-square=numix square png icons

#ICONS=/usr/share/icons/antix-moka
#ICONS=/usr/share/icons/antix-faenza
ICONS=/usr/share/icons/antix-papirus
#ICONS=/usr/share/icons/antix-numix-bevel
#ICONS=/usr/share/icons/antix-numix-square
ICONS2=/usr/share/pixmaps
ICONS3=/usr/share/icons/papirus-antix/48x48/apps

EXCLUDES_DIR=/usr/local/share/excludes 

EDITOR="geany -i"

STARTUP_FILE="$HOME/.desktop-session/startup"

AddStartup="/dev/shm/acc_tmp_01"
RemoveStartup="/dev/shm/acc_tmp_02"

cleanup() {
rm -f $AddStartup >/dev/null 2>&1
rm -f $RemoveStartup >/dev/null 2>&1
}
trap cleanup EXIT

its_alive() {
    # return 0
    local root_fstype=$(df -PT / | tail -n1 | awk '{print $2}')
    case $root_fstype in
        aufs|overlay) return 0 ;;
                   *) return 1 ;;
    esac
}

its_alive && ITS_ALIVE=true

Desktop=$"Desktop" Software=$"Software" System=$"System" Network=$"Network" Shares=$"Shares" Session=$"Session"
Live=$"Live" Disks=$"Disks" Hardware=$"Hardware" Drivers=$"Drivers" Maintenance=$"Maintenance"
dpi_label=$(printf "%s DPI" $"Set Font Size")

vbox() {
    local text="$*"
    local len=${#text}
    #printf "vlen: %6s\n" "$len" >&2
    if [ $len -lt 20 ]; then
        echo '<vbox><hseparator></hseparator></vbox>'
    else
    echo "  <vbox>"
    local item
    for item; do
        echo "$item"
    done
    echo "  </vbox>"
    fi
}

hbox() {
    local text="$*"
    local len=${#text}
    #printf "hlen: %6s\n" "$len" >&2
    [ $len -lt 20 ] && return
    echo "<hbox>"
    local item
    for item; do
        echo "$item"
    done
    echo "</hbox>"
}

vbox_frame_hbox() {
    local text="$*"
    local len=${#text}
    #printf "flen: %6s\n" "$len" >&2
    [ $len -lt 20 ] && return
    echo "<vbox><frame><hbox>"
    local item
    for item; do
        echo "$item"
    done
    echo "</hbox></frame></vbox>"
}

entry() {
    local image="$1" action="$2" text="$3" tooltip="$4"
    [ -n "$tooltip" ] || tooltip=$"(No tooltip for now, sorry.)"
    cat<<Entry
    <hbox>
      <button tooltip-text="$tooltip">
        <input file>$image</input>
        <height>48></height>
        <action>$action</action>
      </button>
      <text use-markup="true" width-chars="32">
        <label>$text</label>
      </text>
    </hbox>
Entry
}

prerequisites() {
    # this convenience function returns a full install dialog within a variable and expects all packages meant to be installed as positional parameters and cares for creation of an install dialog to be applied in entries which are in need of some additional helper tools not installed by default on some antiX flavours. Don't forget to set the $prerequesite_icon and $prerequisites_msg variables before calling.
    # if prerequisites is used in an entry please make sure to wait with reload of acc main window until you find this lockfile removed, so changed button functionality is processed properly at reload; also check for the pid stored within this file to continue if user has closed the installer prematurely:
    acc_install_lock="/dev/shm/acc-install-lock-$$"
    # prepare textstring for output
    if [ $# -gt 1 ]; then
        for i in $@; do
            text="$text, $i"
        done
        text=$(sed 's/^\(.*\), \(.*\)$/\1 '$"and"' \2/' <<<"${text:2}")
    else
        text="$1"
    fi
    # write complete install dialog to a variable
    install_dialog='yad --center --fixed --borders=10 --undecorated --window-icon="'$prerequisites_icon'" --image="'$prerequisites_icon'" --title="'$"Install"" ""$text"'" --text="'$prerequisites_msg'""\n\n""'$"Please install $text packages first."'""\n""'$"Do you want to install the packages now?"'""\n" --button="'$"No thanks"'":1 --button="'$"Install"'":0; if [ $? -eq 0 ]; then setsid -f urxvt -title "'$"Installing prerequisites..."'" -e bash -c "{ echo \$$ > "'$acc_install_lock'"; success=false; sudo apt-get update; if [ $? = 0 ]; then sudo apt-get install '$@'; if [ $? = 0 ]; then echo -e \\\n"'$"Done."'"; success=true; fi; fi; if ! $success; then echo -e \\\n\"'$"Error. Please install $text packages yourself."'\"; fi; rm '$acc_install_lock'; sleep 4; }"; fi'
}

# this convenience function adds missing entries to ~/.desktop-session/startup file in case this must be done by an entry.
# expects mandatory positionals: add_startup "<string_to_be_added>" "<comment_line_to_be_added>"
# in case the line exists, it will silently do nothing, in case the line exists but is commented out the sharp sign preceding the line will be removed.
# Additional third ad libitum positional: "<search_string>" in case the command string feed in first positional includes variable parts. Accepts regex, syntax must match sed and grep regex both.
#add_startup() {    # originally a function, but not accessible from within entries, even after exporting it; temp script files as workaround.
cat<<add_startup >"$AddStartup"
    if [ -z "\$3" ]; then teststring="\$1"; else teststring="\$3"; fi # workaround for variable arguments behind a fixed command string
    if ! grep ^[[:space:]]*"\${teststring}" "$STARTUP_FILE" >/dev/null; then
# We don't care for hard blocked entries for now, this might be a future feature.
#        if grep ^[[:space:]]*[#][#][[:space:]]*"\${teststring}" "$STARTUP_FILE" >/dev/null; then
#            # don’t touch entry if user has hard blocked it
#            yad --center --fixed --borders=10 --undecorated \\
#                --window-icon="error" \\
#                --image="error" \\
#                --title=$"Error"" ""\$1" \\
#                --text=$"Entry \${1/&/＆} is hard blocked""\n"$"by double sharp sign in config file""\n\t$STARTUP_FILE\n"$"Please uncomment it on your own.""\n" \\
#                --button=$"Got it":0
#            #echo $"Entry is hard blocked by double sharp in config file $STARTUP_FILE."" "$"Please uncomment it on your own."
#            exit 1
#            #return 1
#       elif ↓
        if grep ^[[:space:]]*[#][[:space:]]*"\${teststring}"[[:space:]]*[#]*[[:space:]]* "$STARTUP_FILE" >/dev/null; then
            teststring=\${teststring/&/\\\&} # prepare strings for yad
            replacement=\${1/&/\\\&}
            # remove sharp sign to uncomment, only on a single occurence
            sed -i "0,/\${teststring//\//\\/}/{s/^[[:space:]]*#[[:space:]]*\${teststring//\//\\/}.*$/\${replacement//\//\\/}/}" "$STARTUP_FILE"
        else
            # append entry
            echo -e "\n\$2\n\$1" >> "$STARTUP_FILE"
        fi
    fi
add_startup
#}
#export -f add_startup
chmod 755 "$AddStartup"

# counterpart of add_startup() function.
# expects mandatory positionals: disable_startup "<string_to_be_disabled_without_preceeding_sharp>" "<comment_line_to_be_added_if_entry_not_present_yet>"
#disable_startup() {
cat<<disable_startup >"$RemoveStartup"
    if grep ^[[:space:]]*"\${1}" "$STARTUP_FILE" >/dev/null; then
# We don't care for duplicate disabled entries for now, these must have been introduced by the user himself. He might have had a reason for creating these.
#        if grep ^[[:space:]]*[#][[:space:]]*"\${1}"[[:space:]]*[#]*[[:space:]]* "$STARTUP_FILE" >/dev/null || grep ^[[:space:]]*[#][#][[:space:]]*"\${1}"[[:space:]]*[#]*[[:space:]]* "$STARTUP_FILE" >/dev/null; then
#            # remove entry
#            sed -i "/^[[:space:]]*\${1//\//\\/}.*$/d" "$STARTUP_FILE"
#        else
            # add sharp sign to comment out ALL occurrences, including user created duplicates.
            sed -i "s/^[[:space:]]*\(\${1//\//\\/}.*\)$/# \1/" "$STARTUP_FILE"
#        fi
# We don't care for duplicates for now, these must have been introduced by the user himself. He might have had a reason for creating these.
#    else
#        # There is no active entry, but maybe a deactivated one is already present.
#        if ! grep ^[[:space:]]*[#][[:space:]]*"\${1}"[[:space:]]*[#]*[[:space:]]* "$STARTUP_FILE" >/dev/null || ! grep ^[[:space:]]*[#][#][[:space:]]*"\${1}"[[:space:]]*[#]*[[:space:]]* "$STARTUP_FILE" >/dev/null; then
#            # append disabled entry, preceeded by #
#            echo -e "\n\$2\n# \$1" >> "$STARTUP_FILE"
#        fi
    fi
disable_startup
#}
#export -f disable_startup
chmod 755 "$RemoveStartup"

[ -d $HOME/.fluxbox -a -e /usr/share/xsessions/fluxbox.desktop ] && fluxbox_entry=$(entry \
    "$ICONS/gnome-documents.png" \
    "$EDITOR $HOME/.fluxbox/overlay $HOME/.fluxbox/keys $HOME/.fluxbox/init $HOME/.fluxbox/startup $HOME/.fluxbox/apps $HOME/.fluxbox/menu &" \
    $"Edit Fluxbox Settings" \
    $"Modify the Fluxbox window manager configuration files in a text editor")

icewmgui_prog=/usr/local/bin/icewm-manager-gui
test -x $icewmgui_prog && icewmgui_entry=$(entry \
    $ICONS/icewmcc.png \
    "/usr/local/bin/icewm-manager-gui &" \
    $"IceWM Control Centre" \
    $"Manage most popular IceWM window manager settings in a GUI instead of editing its control file manually")

wallpaper_prog=/usr/local/bin/wallpaper
test -x $wallpaper_prog && wallpaper_entry=$(entry \
    $ICONS/preferences-desktop-wallpaper.png \
    "/usr/local/bin/wallpaper &" \
    $"Choose Wallpaper" \
    $"Select the desktop background image or colour.")
    
[ -d $HOME/.icewm -a -e /usr/share/xsessions/icewm.desktop ] && icewm_entry=$(entry \
    $ICONS/gnome-documents.png \
    "$EDITOR $HOME/.icewm/winoptions $HOME/.icewm/preferences $HOME/.icewm/prefoverride $HOME/.icewm/keys $HOME/.icewm/startup $HOME/.icewm/toolbar $HOME/.icewm/menu $HOME/.icewm/menu-applications $HOME/.icewm/personal &" \
    $"Edit IceWM Settings" \
    $"Modify the IceWM window manager configuration files in a text editor")

[ -d $HOME/.jwm -a -e /usr/share/xsessions/jwm.desktop ] && jwm_entry=$(entry \
    $ICONS/gnome-documents.png \
    "$EDITOR $HOME/.jwm/preferences $HOME/.jwm/keys $HOME/.jwm/tray $HOME/.jwm/startup $HOME/.jwmrc $HOME/.jwm/menu &" \
    $"Edit JWM Settings" \
    $"Modify the JWM window manager configuration files in a text editor")

# Edit syslinux.cfg if the device it is on is mounted read-write
grep -q " /live/boot-dev .*\<rw\>" /proc/mounts && bootloader_entry=$(entry \
    $ICONS/preferences-desktop.png \
    "gksu '$EDITOR /live/boot-dev/boot/syslinux/syslinux.cfg /live/boot-dev/boot/grub/grub.cfg' &" \
    $"Edit Bootloader Menu" \
    $"Modify the Syslinux and Grub boot menu configuration files in a text editor")

test -d /usr/local/share/excludes && excludes_entry=$(entry \
    $ICONS/remastersys.png \
    "gksu $EDITOR $EXCLUDES_DIR/*.list &" \
    $"Edit Exclude Files" \
    $"This will open several list files in a text editor, allowing to define what files are NOT to be included when live-remastering, creating an ISO snapshot etc. For example, you might want to add the directories “home/*/.local/share/Trash” and/or “home/*/./cache” to the exclusions for live-remastering, which will otherwise be stored in your boot medium when running live-remaster in „personal” flavour and „storing home folder” in it.")

if test -x /usr/sbin/synaptic; then synaptic_entry=$(entry \
    $ICONS/synaptic.png \
    "gksu synaptic &" \
    $"Manage Packages" \
    $"Add or remove program packages using Synaptic package manager")

elif test -x /usr/local/bin/cli-aptiX; then synaptic_entry=$(entry \
    $ICONS/synaptic.png \
    "desktop-defaults-run -t sudo /usr/local/bin/cli-aptiX --pause &" \
    $"Manage Packages" \
    $"Add or remove program packages using Cli-aptiX package manager")
fi

test -x  /usr/sbin/bootrepair && bootrepair_entry=$(entry \
    $ICONS2/bootrepair.png \
    "gksu bootrepair &" \
    $"Boot Repair" \
    $"Reinstall, Fix, Backup or Restore GRUB configuration or MBR/PBR from within a GUI."  )

test -x /usr/bin/connman-ui-gtk && connman_entry=$(entry \
    $ICONS/connman.png \
    "connman-ui-gtk &" \
    $"WiFi Connect"
    $"Change and manage the wireless connection settings using Connman.")

test -x /usr/bin/connman-gtk && connman_entry=$(entry \
    $ICONS/connman.png \
    "connman-gtk &" \
    $"WiFi Connect" \
    $"Change and manage the wireless connection settings using Connman.")

test -x /usr/bin/cmst && connman_entry=$(entry \
    $ICONS/connman.png \
    "cmst &" \
    $"WiFi Connect" \
    $"Change and manage the wireless connection settings using Connman.")

firewall_prog=/usr/bin/gufw
test -x $firewall_prog  && firewall_entry=$(entry \
    $ICONS/gufw.png \
    "gksu gufw &" \
    $"Firewall Configuration" \
    $"Set up the firewall for your Network connections using gufw.")

backup_prog=/usr/bin/luckybackup
test -x $backup_prog  && backup_entry=$(entry \
    $ICONS/luckybackup.png \
    "gksu luckybackup &" \
    $"System Backup" \
    $"Make a backup of your system using Luckybackup.")

if wpctl status >/dev/null 2>&1; then 
    if which easyeffects > /dev/null && which antiX-equaliser-toggle > /dev/null; then
        equalizer_entry=$(entry \
        $ICONS/com.github.wwmm.easyeffects.png \
        'easyeffects &' \
        $"Equaliser for Pipewire" \
        $"Modify the frequency response characteristics of the audio output.")
        eq_toggle_entry=$(entry \
        $ICONS/easyeffects-toggle.png \
        'antiX-equaliser-toggle &' \
        $"Toggle equaliser" \
        $"A switch to immediately enable or disable PipeWire-equaliser Easyeffects and add or remove it from startup" \
        )
    else
        prerequisites_icon="$ICONS/alsamixer-equalizer.png"
        prerequisites easyeffects lsp-plugins-lv2 antix-equaliser-toggle
        prerequisites_msg=$"Equaliser for Pipewire not found."
        equalizer_entry=$(entry \
        $ICONS/com.github.wwmm.easyeffects.png \
        "xdotool search --name '"$"antiX Control Centre""' windowunmap; \
        { $install_dialog & }; \
        { sleep .5; \
        p=undefined; \
        [ -f $acc_install_lock ] && p=\$(cat $acc_install_lock); \
        while [ -f $acc_install_lock ]; do \
            sleep .1; \
            if ! ps -p \$p >/dev/null 2>&1; then \
                break; \
            fi; \
        done; }; \
        if which easyeffects; then \
            { bash $AddStartup 'easyeffects --gapplication-service' \
            '# Start easyeffects in pseudo-daemonised mode'; }; \
        fi; \
        xdotool search --name '"$"antiX Control Centre""' windowclose; \
        sleep .2; \
        pkill --signal 15 antixcc.sh; \
        sleep .2; \
        antixcc.sh &" \
        $"Equaliser for Pipewire" \
        $"Modify the frequency response characteristics of the audio output."" "$"Equaliser for Pipewire not installed. Installs easyeffects and lsp-plugins-lv2 packages.")
    fi
else
    equalizer_prog=/usr/share/applications/alsamixer-equalizer.desktop
    test -f $equalizer_prog  && equalizer_entry=$(entry \
        $ICONS/alsamixer-equalizer.png \
        "urxvt -e alsamixer -D equalizer &" \
        $"Alsamixer Equalizer" \
        $"Modify the frequency response characteristics of the audio output.")
fi

printer_prog=/usr/bin/system-config-printer
test -x $printer_prog  && printer_entry=$(entry \
    $ICONS/printer.png \
    "system-config-printer &" \
    $"Print Settings" \
    $"Set up your printer. You need to make sure beforehand the cups service is started already.")

livekernel_prog=/usr/local/bin/live-kernel-updater
test -x $livekernel_prog && livekernel_entry=$(entry \
    $ICONS/live-usb-kernel-updater.png \
    "desktop-defaults-run -t sudo /usr/local/bin/live-kernel-updater --pause &" \
    $"Live-USB Kernel Updater" \
    $"Update your Live System with a new kernel. Make sure you have installed the kernel already and remastered the Live device before using the Live kernel updater.")

systemkeyboard_prog=/usr/bin/system-keyboard-qt
test -x $systemkeyboard_prog && systemkeyboard_entry=$(entry \
    $ICONS/im-chooser.png \
    "gksu system-keyboard-qt &" \
    $"Set System Keyboard Layout" \
    $"Add or modify keyboard layouts, e.g. Cyrillic, Chinese or Azerty, Qwertz and Qwerty in multiple variants like Typewriter, Dvorak or Sun.")

kb_layout_prog=/usr/local/bin/antiX-current-kb-layout
if test -x $kb_layout_prog; then
    keyboardlayout_entry=$(entry \
    "$ICONS2/antiX-current-kb-layout.png" \
    "antiX-current-kb-layout &" \
    $"Current Keyboard Layout" \
    $"Displays current keyboard layout, as selected by locale chooser from antiX statusbar (useful if you have to type in some foreign language layouts, the proper characters not being printed on your keys). Reveals second and third level assignements as well.")
else
    prerequisites_icon="$ICONS/antiX-current-kb-layout-CC.png"
    prerequisites_msg=$"antiX-current-kb-layout not found."
    prerequisites antix-current-kb-layout
    keyboardlayout_entry=$(entry \
    "$ICONS/antiX-current-kb-layout-CC.png" \
    "xdotool search --name '"$"antiX Control Centre""' windowunmap; \
      { $install_dialog & }; \
      { sleep .5; \
      p=undefined; \
      [ -f $acc_install_lock ] && p=\$(cat $acc_install_lock); \
      while [ -f $acc_install_lock ]; do \
          sleep .1; \
          if ! ps -p \$p >/dev/null 2>&1; then \
              break; \
          fi; \
      done; }; \
      { antiX-current-kb-layout & }; \
      xdotool search --name '"$"antiX Control Centre""' windowclose; \
      sleep .2; \
      pkill --signal 15 antixcc.sh; \
      sleep .2; \
      antixcc.sh &" \
    $"Current Keyboard Layout" \
    $"Displays current keyboard layout, as selected by locale chooser from antiX statusbar (useful if you have to type in some foreign language layouts, the proper characters not being printed on your keys). Reveals second and third level assignements as well."" "$"antiX-current-kb-layout not installed. Installs antiX-current-kb-layout package and shows then the current layout.")
fi

wallpaper_prog=/usr/local/bin/wallpaper
test -x $wallpaper_prog && wallpaper_entry=$(entry \
    $ICONS/preferences-desktop-wallpaper.png \
    "/usr/local/bin/wallpaper &" \
    $"Choose Wallpaper" \
    $"Select the desktop background image or colour.")

conky_prog=/usr/bin/conky
test -x $conky_prog && test -w $HOME/.conkyrc && conky_entry=$(entry \
    $ICONS/conky.png \
    "desktop-defaults-run -te $HOME/.conkyrc &" \
    $"Edit System Monitor" \
    $"Modify the design of the Conky System monitor on the desktop.")

lxappearance_prog=/usr/bin/lxappearance
test -x $lxappearance_prog && lxappearance_entry=$(entry \
    $ICONS/preferences-desktop-theme.png \
    "lxappearance &" \
    $"Customize Look and Feel" \
    $"Change the design of your desktop, modify details like mouse cursor design etc. using lxappearance.")

compositor_prog=/usr/bin/xcompmgr
if test -x $compositor_prog; then
if ! grep '^[[:space:]]*xcompmgr..*' "$STARTUP_FILE" > /dev/null; then
    compositor_entry=$(entry \
    $ICONS/Logo_compiz-48.png \
    "{ bash $AddStartup 'xcompmgr -f -F &' '## Uncomment to use compositor'; }; { wmctrl -F -c '"$"antiX Control Centre""'; }; \
    if ! pidof xcompmgr; then { xcompmgr -f -F & }; fi; { sleep .5; }; { antixcc.sh & }" \
    $"Activate visual effects" \
    $"Starts Xcompmgr compositor, allowing shading, fading, transparency and some more visual desktop effects.")
else
    compositor_entry=$(entry \
    $ICONS/Logo_compiz-grey-48.png \
    "{ bash $RemoveStartup 'xcompmgr..*' '## Uncomment to use compositor manager'; }; { wmctrl -F -c '"$"antiX Control Centre""'; }; \
    { kill -15 $(pidof xcompmgr 2>/dev/null); }; { sleep .5; }; { antixcc.sh & }" \
    $"Disengage visual effects" \
    $"Deactivates Xcompmgr compositor, disabeling some desktop eye candys like shading, fading, tranparency etc.")
fi
fi

prefapps_prog=/usr/local/bin/desktop-defaults-set
test -x $prefapps_prog && prefapps_entry=$(entry \
    $ICONS/gnome-settings-default-applications.png \
    "desktop-defaults-set &" \
    $"Preferred Applications" \
    $"Select what default programs are used on your system.")

packageinstaller_prog=/usr/bin/packageinstaller
test -x $packageinstaller_prog && packageinstaller_entry=$(entry \
    $ICONS/packageinstaller.png \
    "gksu packageinstaller &" \
    $"Package Installer" \
    $"Install popular programs easily using Package Installer. This tool takes care of all hidden dependencies the default package managers like apt or synaptic neglect.")

antixupdater_prog=/usr/local/bin/yad-updater
test -x $antixupdater_prog && antixupdater_entry=$(entry \
    $ICONS/software-sources.png \
    "/usr/local/bin/yad-updater &" \
    $"antiX Updater" \
    $"Update antiX automatically to the most recent state of the selected repositories.")

antixautoremove_prog=/usr/local/bin/yad-autoremove
test -x $antixautoremove_prog && antixautoremove_entry=$(entry \
    $ICONS/debian-logo.png \
    "/usr/local/bin/yad-autoremove &" \
    $"antiX program remover" \
    $"Removes automatically leftover (orphaned) packages no longer needed on your system.")

sysvconf_prog=/usr/sbin/sysv-rc-conf
test -x $sysvconf_prog && sysvconf_entry=$(entry \
    $ICONS/choose-startup-services.png \
    "rc-conf-wrapper.sh &" \
    $"Choose Startup Services" \
    $"Select what system services should be started automatically when booting antiX (sysVinit).")

runitconf_prog=/usr/local/bin/runit-service-manager.sh
test -x $runitconf_prog && runitconf_entry=$(entry \
    $ICONS/choose-startup-services.png \
    "gksu runit-service-manager.sh &" \
    $"Choose Startup Services" \
    $"Select what system services should be started automatically when booting antiX (runit).")

ufwtoggle_prog=/usr/local/bin/antix_firewall_toggle
test -x $ufwtoggle_prog && ufwtoggle_entry=$(entry \
    $ICONS/gufw.png \
    "/usr/local/bin/antix_firewall_toggle &" \
    $"Toggle Firewall on/off" \
    $"Switch the state of your network firewall on or off using ufw.")

tzdata_prog=/usr/local/bin/set_time-and_date.sh
test -x $tzdata_prog && tzdata_entry=$(entry \
    $ICONS/time-admin.png \
    "/usr/local/bin/set_time-and_date.sh &" \
    $"Set Date and Time" \
    $"Change and adjust date and time settings of your system.")
    
process_management_prog=/usr/bin/htop
test -x $process_management_prog && process_entry=$(entry \
    $ICONS/sheets.png \
    "urxvt -e htop &" \
    $"Process Manager" \
    $"View, pause, kill or nice processes in a console-gui"" "$"Use mouse for all controls.")

memorymanager_prog=/usr/local/bin/antiX-memory-manager
test -x $memorymanager_prog && memorymanager_entry=$(entry \
    $ICONS3/antiXmm.png \
    "urxvt -e sudo bash -c '/usr/local/bin/antiX-memory-manager &'" \
    $"Memory Manager" \
    $"Optimise memory economy by applying kernel memory compression. Activate, deactivate, configure zram and zswap, check usage stats.")

localisation_prog=/usr/local/bin/locale-antix
test -x $localisation_prog && localisation_entry=$(entry \
    $ICONS/preferences-desktop-locale.png \
    "gksu /usr/local/bin/locale-antix &" \
    $"System Language Manager" \
    $"Change Language and other locale options including downloading localised LibreOffice")

ceni_prog=/usr/sbin/ceni
test -x $ceni_prog && ceni_entry=$(entry \
    $ICONS/ceni.png \
    "desktop-defaults-run -t sudo ceni &" \
    $"Network Interfaces" \
    $"Set up the network interfaces present on your device using Ceni.")

wifi_prog=/usr/local/bin/antix-wifi-switch
test -x $wifi_prog && wifi_entry=$(entry \
    $ICONS/nm-device-wireless.png \
    "antix-wifi-switch &" \
    $"Select wifi Application" \
    $"Select which wireless management program should be used.")

connectshares_prog=/usr/local/bin/connectshares-config
test -x $connectshares_prog && connectshares_entry=$(entry \
    $ICONS/connectshares-config.png \
    "connectshares-config &" \
    $"ConnectShares Configuration" \
    $"Configure Connections to Windows or SAMBA shares in your LAN or WAN.")

disconnectshares_prog=/usr/local/bin/disconnectshares
test -x $disconnectshares_prog && disconnectshares_entry=$(entry \
    $ICONS/disconnectshares.png \
    "disconnectshares &" \
    $" DisconnectShares" \
    $"Disconnect from all currently connected Windows or SAMBA shares. Make sure the shares are not in use by any programs before executing.")

droopy_prog=/usr/local/bin/droopy.sh
test -x $droopy_prog && droopy_entry=$(entry \
    $ICONS/droopy.png \
    "droopy.sh &" \
    $"Droopy (File Sharing)" \
     $"Serve files via Python web server")

shared_prog=/usr/local/bin/antiX-samba-mgr
if test -x $shared_prog; then
    shared_entry=$(entry \
    $ICONS3/antiX-smb-mgr02.png \
    "/usr/local/bin/antiX-samba-mgr &" \
    $"Shared Folders" \
     $"Mount and share folders or printers easily in your LAN from and with other PCs running diverse OS’ (Windows, Apple, Linux, BSD etc.) in a GUI suite. antiX Samba manager guides you through shares setup and allows to mount remote shares to arbitrary empty folders within your file system and share any folder on your device.")
else
    prerequisites_icon="$ICONS/antiX-smb-mgr-CC.png"
    prerequisites_msg=$"antiX-samba-mgr not found."
    prerequisites antix-samba-manager
    shared_entry=$(entry \
    $ICONS/antiX-smb-mgr-CC.png \
    "xdotool search --name '"$"antiX Control Centre""' windowunmap; \
      { $install_dialog & }; \
      { sleep .5; \
      p=undefined; \
      [ -f $acc_install_lock ] && p=\$(cat $acc_install_lock); \
      while [ -f $acc_install_lock ]; do \
          sleep .1; \
          if ! ps -p \$p >/dev/null 2>&1; then \
              break; \
          fi; \
      done; }; \
      { /usr/local/bin/antiX-samba-mgr & }; \
      xdotool search --name '"$"antiX Control Centre""' windowclose; \
      sleep .2; \
      pkill --signal 15 antixcc.sh; \
      sleep .2; \
      antixcc.sh &" \
    $"Shared Folders" \
    $"Mount and share folders or printers easily in your LAN from and with other PCs running diverse OS’ (Windows, Apple, Linux, BSD etc.) in a GUI suite. antiX Samba manager guides you through shares setup and allows to mount remote shares to arbitrary empty folders within your file system and share any folder on your device."" "$"Currently antiX Samba manager package is not installed. This installs an runs it.")
fi

cloud_prog=/usr/local/bin/antix-cloud
test -x $cloud_prog && cloud_entry=$(entry \
    $ICONS/folder-red-meocloud.png \
    "/usr/local/bin/antix-cloud &" \
    $"Access Cloud Storage" \
     $"Allows to automatically configure GoogleDrive and OneDrive, in rclone, or to manually configure (almost) any Cloud Service, and then mount it and access it in the default File Manager")

assistant_prog=/usr/local/bin/1-to-1_assistance.sh
test -x $assistant_prog && assistant_entry=$(entry \
    $ICONS2/1-to-1_assistance.png \
    "1-to-1_assistance.sh &" \
    $"1-to-1 Assistance" \
    $"A simple way to privately share the desktop of one system with another system.")

voice_prog=/usr/local/bin/1-to-1_voice.sh
test -x $voice_prog && voice_entry=$(entry \
    $ICONS2/1-to-1_voice.png \
    "1-to-1_voice.sh &" \
    $"1-to-1 Voice" \
    $"A simple way to talk privately with the user of another system.")

sshconduit_prog=/usr/local/bin/ssh-conduit.sh
test -x $sshconduit_prog && sshconduit_entry=$(entry \
    $ICONS2/ssh-conduit.png \
    "ssh-conduit.sh &" \
    $"SSH Conduit" \
    $"Use remote resouces via an ssh encypted connection")

gnomeppp_prog=/usr/bin/gnome-ppp
test -x $gnomeppp_prog && gnomeppp_entry=$(entry \
    $ICONS/gnome-ppp.png \
    "gnome-ppp &" \
    $"Dial-Up Configuaration (GNOME PPP)" \
    $"Dialup connection tool")

wpasupplicant_prog=/usr/sbin/wpa_gui
test -x $wpasupplicant_prog && wpasupplicant_entry=$(entry \
    $ICONS/wpa_gui.png \
    "/usr/sbin/wpa_gui &" \
    $"WPA Supplicant Configuration" \
    $"Graphical user interface for wpa_supplicant")

pppoeconf_prog=/usr/sbin/pppoeconf
test -x $pppoeconf_prog && pppoeconf_entry=$(entry \
    $ICONS/internet-telephony.png \
    "desktop-defaults-run -t /usr/sbin/pppoeconf &" \
    $"ADSL/PPPOE Configuration" \
    $"User-friendly tool for initial configuration of a DSL (PPPoE) connection.")

adblock_prog=/usr/local/bin/block-advert.sh
test -x $adblock_prog && adblock_entry=$(entry \
    $ICONS/advert-block.png \
    "gksu block-advert.sh &" \
    $"Adblock" \
    $"Block adverts via /etc/hosts file")

hostname_prog=/usr/local/bin/antiX-hostname-changer
test -x $hostname_prog && hostname_entry=$(entry \
    $ICONS3/antiXhnc.png \
    "urxvt -e sudo bash -c 'antiX-hostname-changer &'" \
    $"Hostname Changer" \
    $"Changes the Computer name (hostname) in antiX for your local network. As a consequence this will change the displayed computer name in console windows. The hostname must be unique in your local network domain.")

login_prog=/usr/local/bin/login-config-antix
test -x $login_prog && login_entry=$(entry \
    $ICONS/preferences-system-login.png \
    "gksu login-config-antix &" \
    $"Login Manager" \
    $"Set default user, autologin, numeric keypad, login-design and -background ")

slim_cc=/usr/local/bin/antixccslim.sh
slim_prog=/usr/bin/slim
test -x $slim_prog && test -x $slim_cc && slim_entry=$(entry \
    $ICONS/preferences-desktop-wallpaper.png \
    "gksu antixccslim.sh &" \
    $"Change Slim Background")

grub_prog=/usr/local/bin/antixccgrub.sh
test -x $grub_prog && grub_entry=$(entry \
    $ICONS/screensaver.png \
    "gksu antixccgrub.sh &" \
    $"Set Grub Boot Image (png only)"\
    $"Set Grub Boot Image (png only)")

which ${EDITOR%% *} &>/dev/null && confroot_entry=$(entry \
    $ICONS/gnome-documents.png \
    "gksu $EDITOR /etc/fstab /etc/default/keyboard /etc/grub.d/* /etc/slimski.local.conf /etc/apt/sources.list.d/*.list &" \
    $"Edit Config Files" \
    $"Manually edit the antiX startup configuration files for keyboard, grub, slimski login manager, and the package source repositories for your system.")

arandr_prog=/usr/bin/arandr
test -x $arandr_prog && arandr_entry=$(entry \
    $ICONS/video-display.png \
    "arandr &" \
    $"Set Screen Resolution (ARandR)" \
    $"Change resolution, orientation, aspect (format), output device (monitor, tv, svga etc.) for the primary and secondary display device.")

gksu_prog=/usr/bin/gksu-properties
test -x $gksu_prog && gksu_entry=$(entry \
    $ICONS/gksu.png \
    "gksu-properties &" \
    $"Password Prompt (su/sudo)" \
    $"Switch between su and sudo style of granting root access.")

slimlogin_prog=/usr/local/bin/slim-login
test -x $slimlogin_prog && slimlogin_entry=$(entry \
    $ICONS/preferences-system-login.png \
    "gksu slim-login &" \
    $"Set Auto-Login"
    $"Set up or disable automatic login at system startup.")

screenblank_prog=/usr/local/bin/set-screen-blank
test -x $screenblank_prog && screenblank_entry=$(entry \
    $ICONS/set-screen-blanking.png \
    "set-screen-blank &" \
    $"Set Screen Blanking" \
    $"Define amount of time after which screen will blank and monitor power off, or disable screen blanking.")

desktopsession_dir=/usr/share/doc/desktop-session-antix
test -d $desktopsession_dir  && desktopsession_entry=$(entry \
    $ICONS/preferences-system-session.png \
    "$EDITOR $HOME/.desktop-session/*.conf $HOME/.desktop-session/startup &" \
    $"User Desktop-Session" \
    $"Manually edit the antiX desktop configuration files for startup, automount, desktop-defaults, desktop-session, mouse and wallpapers for you user account.")

if ! grep '^[[:space:]]*suspend_if_idle' "$STARTUP_FILE" > /dev/null; then
    suspend_entry=$(entry \
    $ICONS2/papirus/suspend.png \
    "xdotool search --name '"$"antiX Control Centre""' windowunmap; \
    { timeout=\$(yad --center --title='"$"Suspend computer if idle for...""' --borders=20 --width=400 \
	--window-icon=$ICONS2/papirus/suspend.png --form \
    --field='"$"Select number of minutes:":NUM"' 15!1..600!1!0 | sed 's/.$//'); }; \
	if ! test -z \$timeout; then \
	{ bash $AddStartup \"suspend_if_idle \$timeout &\" \
    '## Uncomment and set desired value to activate suspend timer at startup' \
    'suspend_if_idle [[:digit:]][[:digit:]]*[[:space:]][[:space:]]*&'; }; \
    { suspend_if_idle \$timeout & }; \
    xdotool search --name '"$"antiX Control Centre""' windowclose; sleep .2; \
    pkill --signal 15 antixcc.sh; sleep .2; { antixcc.sh & }; \
    else xdotool search --name '"$"antiX Control Centre""' windowmap; fi" \
    $"Engage AutoSuspend" \
    $"Starts suspend timeout and adds the selected amount of minutes to startup configuration.")
else
    CURRENT_TIMEOUT=$(grep ^[[:space:]]*suspend_if_idle $STARTUP_FILE | sed 's/^[[:space:]]*//' | cut -d' ' -f2)
    suspend_entry=$(entry \
    $ICONS2/papirus/suspend_grey.png \
    "{ bash $RemoveStartup 'suspend_if_idle' '## Uncomment and set desired value to activate suspend timer at startup'; }; \
    { wmctrl -F -c '"$"antiX Control Centre""'; }; if ! pidof suspend_if_idle ; then { suspend_if_idle 0 & }; fi; { sleep .5; }; { antixcc.sh & }" \
    $"Disengage AutoSuspend" \
    $"Stops suspend timeout and disables it in startup configuration. Currently timeout is configured to $CURRENT_TIMEOUT minutes.")
fi

if ! grep '^[[:space:]]*clipit[[:space:]]*&' "$STARTUP_FILE" > /dev/null; then
    clipit_entry=$(entry \
    $ICONS/clipit-trayicon.png \
    "{ bash $AddStartup 'clipit &' '## Uncomment to use clipboard manager'; }; { wmctrl -F -c '"$"antiX Control Centre""'; }; \
    if ! pidof clipit; then { clipit & }; fi; { sleep .5; }; { antixcc.sh & }" \
    $"Activate Clipboard manager" \
    $"Starts extended clipboard functionality and puts an icon for management access to system tray")
else
    clipit_entry=$(entry \
    $ICONS/clipit-trayicon-offline.png \
    "{ bash $RemoveStartup 'clipit &' '## Uncomment to use clipboard manager'; }; { wmctrl -F -c '"$"antiX Control Centre""'; }; \
    { kill -15 $(pidof clipit 2>/dev/null); }; { sleep .5; }; { antixcc.sh & }" \
    $"Disengage Clipboard manager" \
    $"Exits extended clipboard functionality and removes the icon for management access from system tray")
fi

automount_prog=/usr/local/bin/automount-config
test -x $automount_prog && automount_entry=$(entry \
    $ICONS/mountbox.png \
    "automount-config &" \
    $"Configure Automount" \
    $"Configure automounting and autoplay of USB- and Optical CD/DVD-devices, and the behaviour of file managers when a new medium was recognised.")

mountbox_prog=/usr/local/bin/mountbox
test -x $mountbox_prog && mountbox_entry=$(entry \
    $ICONS/mountbox.png \
    "mountbox &" \
    $"Mount Connected Devices" \
    $"Tool to mount devices")

liveusb_prog_g=/usr/bin/live-usb-maker-gui-antix
liveusb_prog=/usr/local/bin/live-usb-maker
if test -x $liveusb_prog_g; then
liveusb_entry=$(entry \
    $ICONS/live-usb-maker.png \
    "gksu live-usb-maker-gui-antix &" \
    $"Live USB Maker (gui)" \
    $"Create a live USB from an ISO.")

elif test -x $liveusb_prog; then
liveusb_entry=$(entry \
    $ICONS/live-usb-maker.png \
     "desktop-defaults-run sudo &live-usb-maker &" \
     $"Live USB Maker (cli)"
     $"Create a live USB from an ISO, console version.")
fi

installer_prog=/usr/sbin/minstall
[ -x $installer_prog -a -n "$ITS_ALIVE" ] && installer_entry=$(entry \
    $ICONS2/msystem.png \
    "gksu $installer_prog &" \
    $"Install antiX Linux" \
    $"This installs antiX to your hard drive.")

diskmanager_prog=/usr/sbin/disk-manager
test -x $diskmanager_prog && diskmanager_entry=$(entry \
    $ICONS/disk-manager.png \
    "gksu $diskmanager_prog &" \
    $"Disk Manager" \
    $"Manage filesystem configuration")

partimage_prog=/usr/sbin/partimage
test -x $partimage_prog && partimage_entry=$(entry \
    $ICONS/drive-harddisk-system.png \
    "desktop-defaults-run -t sudo partimage &" \
    $"Image a Partition" \
    $"Backup partitions into a compressed image file")

grsync_prog=/usr/bin/grsync
test -x $grsync_prog && grsync_entry=$(entry \
    $ICONS/grsync.png \
    "grsync &" \
    $"Synchronize Directories" \
    $"A simple graphical interface for the rsync command line program.")

gparted_prog=/usr/sbin/gparted
test -x $gparted_prog && gparted_entry=$(entry \
    $ICONS/gparted.png \
    "gksu gparted &" \
    $"Partition a Drive" \
    $"Use gparted partitioning program to (re-)partition drives, (re-)format, check, label, resize and move partitions, manage partition flags, (re-)write partition tables MBR, GPT and some more, edit UUIDs etc.")

drive_analysing_program=/usr/bin/baobab
if test -x $drive_analysing_program; then
    drap_entry=$(entry \
    $ICONS/baobab.png \
    "baobab &" \
    $"Disk Usage Analyser" \
    $"Explore in a Diagram what files eat up all the space on your partitions.")
else
    prerequisites_icon="$ICONS/baobab.png"
    prerequisites_msg=$"Baobab not found."
    prerequisites baobab
    drap_entry=$(entry \
    $ICONS/baobab.png \
    "xdotool search --name '"$"antiX Control Centre""' windowunmap; \
      { $install_dialog & }; \
      { sleep .5; \
      p=undefined; \
      [ -f $acc_install_lock ] && p=\$(cat $acc_install_lock); \
      while [ -f $acc_install_lock ]; do \
          sleep .1; \
          if ! ps -p \$p >/dev/null 2>&1; then \
              break; \
          fi; \
      done; }; \
      xdotool search --name '"$"antiX Control Centre""' windowclose; \
      sleep .2; \
      pkill --signal 15 antixcc.sh; \
      sleep .2; \
      antixcc.sh &" \
    $"Disk Usage Analyser" \
    $"Explore in a Diagram what files eat up all the space on your partitions."" "$"Baobab not installed. This installs Baobab first.")
fi

setdpi_prog=/usr/local/bin/set-dpi
test -x $setdpi_prog && setdpi_entry=$(entry \
    $ICONS/fonts.png \
    "gksu set-dpi &" \
    "$dpi_label" \
    $"Change the size factor of screen font")

inxi_prog=/usr/local/bin/inxi-gui
test -x $inxi_prog && inxi_entry=$(entry \
    $ICONS/info_blue.png \
    "inxi-gui &" \
    $"PC Information" \
    $"Gather, display and store in-depth technical information about your device")

mouse_prog=/usr/local/bin/ds-mouse
test -x $mouse_prog && mouse_entry=$(entry \
    $ICONS/input-mouse.png \
    "ds-mouse &" \
    $"Mouse Configuration" \
    $"Modify the properties of your pointer device, e.g. set left hand mouse, set acceleration and threshold, double click period, pointer design and size etc. or set touchpad lockout")

pointing_prog=/usr/local/bin/antiX-pdm
test -x $pointing_prog && pointing_entry=$(entry \
    $ICONS/input-mouse.png \
    "antiX-pdm &" \
    $"Pointing Device Manager" \
    $"Configure touchpad, mouse, and other pointing input devices")

soundcard_prog=/usr/local/bin/alsa-set-default-card
test -x $soundcard_prog && soundcard_entry=$(entry \
    $ICONS/soundcard.png \
    "alsa-set-default-card &" \
    $"Sound Card Chooser" \
    $"Select the default soundcard device to be used.")

# deal with the two mixer levels for pipewire an plain alsa support
mixer_prog=/usr/bin/alsamixer
pw_mixer_prog=/usr/bin/pavucontrol
if wpctl status >/dev/null 2>&1; then 
    # entry for the aditional mixer on pipewire level
    test -x $pw_mixer_prog && pavucontrol_entry=$(entry \
    $ICONS/multimedia-volume-control.png \
    "pavucontrol &" \
    $"Adjust Pipewire-Layer Mixer" \
    $"This provides the volume and device control for the additional PipeWire sound server layer, running on top of ALSA. Includes a tab to select the pipewire device-preset to be applied (e.g. »analog stereo duplex« or »pro-audio« etc).")
    # set modified text and tooltip for alsa mixer entry, which is the primary level mixer as long as pipwire, using pavucontrol, is up.
    mixer_buttontext=$"Basic System Mixer Adjustment"
    mixer_tooltip=$"This provides sliders on the basic ALSA level for all the available playback and recording channels of your soundcards, and switches for muting/unmuting them, as well as switches for additional functions like hardware loopback, auto-mute, dynamic loudness and the slider for the pre-amplifier."" "$"Try F6 button for managing sliders of your true hardware device(s) instead of the »pipewire« alsa device."" "$"Use mouse for all controls."" "$"Alternatively:"" "$"Use right or left arrow keys ← → to scroll to sliders out of sight, use up and down arrow keys ↑↓ to increase or decrease slider setting of highlighted slider, use m key to toggle mute, and +/- keys for other switches."
else
    pavucontrol_entry=""
    mixer_buttontext=$"Adjust Mixer"
    mixer_tooltip=$"This provides sliders for all the available playback and recording channels of your soundcards, and switches for muting/unmuting them, as well as switches for additional functions like hardware loopback, auto-mute, dynamic loudness and the slider for the pre-amplifier"". "$"Use mouse for all controls."" "$"Alternatively:"" "$"Use right or left arrow keys ← → to scroll to sliders out of sight, use up and down arrow keys ↑↓ to increase or decrease slider setting of highlighted slider, use m key to toggle mute, and +/- keys for other switches."
fi
test -x $mixer_prog && mixer_entry=$(entry \
    $ICONS/audio-volume-high-panel.png \
    "urxvt -e alsamixer &" \
    "$mixer_buttontext" \
    "$mixer_tooltip")

ddm_prog=/usr/bin/ddm-mx
test -x $ddm_prog && nvdriver_entry=$(entry \
    $ICONS/nvidia-settings.png \
    "desktop-defaults-run -t su-to-root -c '/usr/bin/ddm-mx -i nvidia' &" \
    $"Nvidia Driver Installer" \
    $"Install proprietary graphic device drivers for recent nvidia GPUs")

snapshot_prog=/usr/bin/iso-snapshot
test -x $snapshot_prog && snapshot_entry=$(entry \
    $ICONS/gnome-do.png \
    "gksu iso-snapshot &" \
    $"ISO Snapshot" \
    $"Create an ISO image of your currently running system, containing all installed programs and setup configurations.")

soundtest_prog=/usr/bin/speaker-test
if ! wpctl status >/dev/null 2>&1; then
    soundtest_device=""
else
    #soundtest_device="-D pulse"    # for antiX 23.0
    soundtest_device="-D pipewire"  # for antiX 23.1
fi
test -x $soundtest_prog  && soundtest_entry=$(entry \
    $ICONS/preferences-desktop-sound.png \
    "desktop-defaults-run -t speaker-test $soundtest_device --channels 2 --test wav --nloops 3 &" \
    $"Test Sound" \
    $"Check the system audio output channels.")

pipewiretoggle_prog=/usr/local/bin/toggle_pipewire
if wpctl status >/dev/null 2>&1; then
    pipewiretoggle_icon="$ICONS/gnome-audio-red.png"
    pipewiretoggle_buttontext=$"Disable PipeWire"
    pipewiretoggle_tooltip=$"Instantly disable PipeWire audio server"" "$"and remove it from system startup."
else
    pipewiretoggle_icon="$ICONS/gnome-audio.png"
    pipewiretoggle_buttontext=$"Enable PipeWire"
    pipewiretoggle_tooltip=$"Instantly enable PipeWire audio server"" "$"and remove it from system startup."
fi
test -x $pipewiretoggle_prog  && pipewiretoggle_entry=$(entry \
    $pipewiretoggle_icon \
    "{ bash toggle_pipewire; }; { wmctrl -F -c '"$"antiX Control Centre""'; }; { sleep .5; }; { antixcc.sh & }" \
    "$pipewiretoggle_buttontext" \
    "$pipewiretoggle_tooltip")

menumanager_prog=/usr/local/bin/menu_manager.sh
test -x $menumanager_prog && menumanager_entry=$(entry \
    $ICONS/menu-editor.png \
    "sudo menu_manager.sh &" \
    $"Menu Editor" \
    $"Activate and Deactivate entries in the Applications- and the Personal submenu of antiX System Main Menu.")

usermanager_prog=/usr/bin/antix-user
test -x $usermanager_prog && usermanager_entry=$(entry \
    $ICONS/user-manager.png \
    "gksu antix-user &" \
    $"User Manager" \
    $"Manage antiX system user accounts and user groups. Add or change passwords. Restore defaults")

galternatives_prog=/usr/bin/galternatives
test -x $galternatives_prog && galternatives_entry=$(entry \
    $ICONS/galternatives.png \
    "gksu galternatives &" \
    $"Alternatives Configurator" \
    $"Select the default programs used for specific tasks (e.g. like taking screenshots) on your antiX system.")

codecs_prog=/usr/bin/codecs
test -x $codecs_prog && codecs_entry=$(entry \
    $ICONS/codecs.png \
    "gksu codecs &" \
    $"Codecs Installer" \
    $"Simple install of restricted codecs")

netassist_prog=/usr/sbin/network-assistant
test -x $netassist_prog && netassist_entry=$(entry \
    $ICONS/network-assistant.png \
    "gksu network-assistant &" \
    $"Network Assistant" \
    $"Some basic networking checks in a GUI")

repomanager_prog=/usr/bin/repo-manager
test -x $repomanager_prog && repomanager_entry=$(entry \
    $ICONS/repo-manager.png \
    "gksu repo-manager &" \
    $"Repo Manager" \
    $"Select the mirror for program package installation used by package management tools like apt, antiX package manager and Synaptic. Activate or deactivate preconfigured repositories.")

which backlight-brightness &>/dev/null && [ -n "$(ls /sys/class/backlight 2>/dev/null)" ] \
    && backlight_entry=$(entry \
    $ICONS/backlight-brightness.png \
    "desktop-defaults-run -t backlight-brightness &" \
    $"Backlight Brightness" \
    $"Adjust the brightness of the backlight from within a terminal.")

if which rescan-scsi-bus.sh > /dev/null; then
    scsi_rescan_entry=$(entry \
    $ICONS3/Noia_64_apps_kcmscsi.png \
    'urxvt -icon '$ICONS3/Noia_64_apps_kcmscsi.png' -title '\"$"Scanning for SCSI devices..."\"' -e bash -c "{ gksu -- rescan-scsi-bus.sh -a -l -w -c && sleep 4; }" &' \
    $"SCSI Bus rescan" \
    $"Search for and activate SCSI devices (e.g. document-scanners) powered on after system startup.")
else
    prerequisites_icon="$ICONS3/Noia_64_apps_kcmscsi.png"
    prerequisites_msg=$"SCSI-Tools not found."
    prerequisites sg3-utils scsitools
    scsi_rescan_entry=$(entry \
    $ICONS3/Noia_64_apps_kcmscsi.png \
    "xdotool search --name '"$"antiX Control Centre""' windowunmap; \
      { $install_dialog & }; \
      { sleep .5; \
      p=undefined; \
      [ -f $acc_install_lock ] && p=\$(cat $acc_install_lock); \
      while [ -f $acc_install_lock ]; do \
          sleep .1; \
          if ! ps -p \$p >/dev/null 2>&1; then \
              break; \
          fi; \
      done; }; \
      xdotool search --name '"$"antiX Control Centre""' windowclose; \
      sleep .2; \
      pkill --signal 15 antixcc.sh; \
      sleep .2; \
      antixcc.sh &" \
    $"SCSI Bus rescan" \
    $"Search for and activate SCSI devices (e.g. document-scanners) powered on after system startup."" "$"SCSI-tools not installed. Installs sg3-utils and scsitools packages.")
fi

[ -e /etc/live/config/save-persist -o -e /etc/live/config/persist-save.conf ]  && persist_save=$(entry \
    $ICONS/palimpsest.png \
    "gksu persist-save &" \
    $"Save Root Persistence" \
    $"Save filesystem changes when running persistence")

[ -e /etc/live/config/remasterable -o -e /etc/live/config/remaster-live.conf ] && live_remaster=$(entry \
    $ICONS/remastersys.png \
    "gksu live-remaster &" \
    $"Remaster-Customize Live" \
    $"Remaster your Live USB device to your current system state. The remastered device will contain all currently installed and updated programs. Use personal to make your individual settings permanent. In order to make an installed kernel active use the antiX Live kernel updater tool once the kernel was integrated into the Live USB device by using this remaster tool. All this applies also to antiX frugal installations.")

live_tab=$(cat<<Live_Tab
$(vbox_frame_hbox \
"$(vbox \
"$(entry "$ICONS/pref.png" "gksu persist-config &" $"Configure Live Persistence" \
$"Set up the way how Live Persistence will save changes to the persistence container file residing in USB device on shutdown (Automatic, Semiautomatic, Manually etc.)")" \
"$livekernel_entry" "$bootloader_entry" "$persist_save")" \
"$(vbox \
"$(entry $ICONS/persist-makefs.png "gksu persist-makefs &" $"Set Up Live Persistence" $"Set up persistence by creating a persistence container file on the live USB device, allowing to run the live antiX system like an installed system, either for Root file system or for User’s Home folder or for both. Also resize, change device or path to container, manage deletion of formerly used persistence- or remastered linuxfs-containers.")" \
"$excludes_entry" "$live_remaster" "$installer_entry")")
Live_Tab
)

# If we are on a live system then ...
if grep -q " /live/aufs " /proc/mounts; then
    tab_labels="$Desktop|$Software|$System|$Network|$Shares|$Session|$Live|$Disks|$Hardware|$Drivers|$Maintenance"

else
    tab_labels="$Desktop|$Software|$System|$Network|$Shares|$Session|$Disks|$Hardware|$Drivers|$Maintenance"
    live_tab=
fi

windowheader=$"antiX Control Centre"  # Dirty workaround to make gettext translation work within the heredoc
export ControlCenter=$(cat<<Control_Center
<window title="$windowheader" window-position="1" icon-name="control-centre-antix">
  <vbox>
<notebook tab-pos="0" labels="$tab_labels">
$(vbox_frame_hbox \
"$(vbox "$wallpaper_entry" "$icewm_entry" "$jwm_entry" "$fluxbox_entry")" \
"$(vbox "$setdpi_entry" "$lxappearance_entry" "$conky_entry" "$prefapps_entry")" )

$(vbox_frame_hbox \
"$(vbox "$antixupdater_entry" "$antixautoremove_entry" "$synaptic_entry")" \
"$(vbox "$packageinstaller_entry" "$repomanager_entry")" )

$(vbox_frame_hbox \
"$(vbox "$icewmgui_entry" "$sysvconf_entry"  "$runitconf_entry" "$galternatives_entry" "$localisation_entry" "$compositor_entry" )" \
"$(vbox "$confroot_entry" "$systemkeyboard_entry" "$keyboardlayout_entry" "$tzdata_entry" "$process_entry" "$memorymanager_entry")" )

$(vbox_frame_hbox \
"$(vbox "$wifi_entry $connman_entry" "$ceni_entry" "$pppoeconf_entry" "$hostname_entry")" \
"$(vbox "$gnomeppp_entry" "$wpasupplicant_entry" "$firewall_entry" "$adblock_entry" "$ufwtoggle_entry")" )

$(vbox_frame_hbox \
"$(vbox "$connectshares_entry" "$droopy_entry"  "$cloud_entry" "$assistant_entry" "$voice_entry")" \
"$(vbox "$disconnectshares_entry" "$shared_entry" "$sshconduit_entry")" )

$(vbox_frame_hbox \
"$(vbox "$arandr_entry" "$gksu_entry" "$grub_entry" "$suspend_entry")" \
"$(vbox "$login_entry" "$screenblank_entry" "$desktopsession_entry" "$clipit_entry")")

$live_tab

$(vbox_frame_hbox \
"$(vbox "$automount_entry" "$mountbox_entry" "$diskmanager_entry" "$drap_entry")" \
"$(vbox "$liveusb_entry" "$partimage_entry" "$grsync_entry" "$gparted_entry")")

$(vbox_frame_hbox \
"$(vbox "$printer_entry" "$inxi_entry" "$mouse_entry" "$pointing_entry" "$backlight_entry" "$scsi_rescan_entry" "$soundcard_entry")" \
"$(vbox "$pipewiretoggle_entry" "$soundtest_entry" "$mixer_entry" "$pavucontrol_entry" "$eq_toggle_entry" "$equalizer_entry")")

$(vbox_frame_hbox \
"$(vbox "$nvdriver_entry" "$ndiswrapper_entry")" \
"$(vbox "$codecs_entry")" )

$(vbox_frame_hbox \
"$(vbox "$snapshot_entry" "$backup_entry" "$netassist_entry")" \
"$(vbox "$bootrepair_entry" "$menumanager_entry" "$usermanager_entry")" )

</notebook>
</vbox>
</window>
Control_Center
)

case $1 in
    -d|--debug) echo "$ControlCenter" > ccdlg.txt; cat -n ccdlg.txt ; exit ;;
esac

gtkdialog --program=ControlCenter
#unset ControlCenter
