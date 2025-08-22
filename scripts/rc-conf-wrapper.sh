#!/bin/bash

if [ -f /run/runit.stopit ] && [ -x /usr/local/bin/runit-service-manager.sh ]; then
    gksu runit-service-manager.sh
else
    desktop-defaults-run -t sudo sysv-rc-conf && sudo killall sysv-rc-conf
fi

