#!/bin/bash

#####################################################################################
#                        FlightMate SETUP SCRIPT FORKED                         #
#####################################################################################
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2016 Joseph A. Prochazka                                       #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


## CHECK IF SCRIPT WAS RAN USING SUDO

if [ "$(id -u)" != "0" ]; then
    echo -e "\033[33m"
    echo "This script must be ran using sudo or as root."
    echo -e "\033[37m"
    exit 1
fi

## CHECK FOR PACKAGES NEEDED BY THIS SCRIPT

echo -e "\033[33m"
echo "Checking for packages needed to run this script..."

if [ $(dpkg-query -W -f='${STATUS}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Installing the curl package..."
    echo -e "\033[37m"
    sudo apt-get update
    sudo apt-get install -y curl
fi
echo -e "\033[37m"

## ASSIGN VARIABLES

LOGDIRECTORY="$PWD/logs"
MLATCLIENTVERSION="0.2.6"
MLATCLIENTTAG="v0.2.6"

## WHIPTAIL DIALOGS

BACKTITLETEXT="FlightMate Setup Script"

whiptail --backtitle "$BACKTITLETEXT" --title "$BACKTITLETEXT" --yesno "Thanks for choosing to share your data with FlightMate!\n\nFlightMate.cfis a co-op of ADS-B/Mode S/MLAT feeders from around the New Zealand. This script will configure your current ADS-B receiver to share your feeders' data with FlightMate.\n\nWould you like to continue setup?" 13 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    exit 0
fi

flightmateUSERNAME=$(whiptail --backtitle "$BACKTITLETEXT" --title "FlightMate User Name" --nocancel --inputbox "\nPlease enter your FlightMate user name.\n\nIf you have more than one receiver, this username should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 3>&1 1>&2 2>&3)
RECEIVERPORT=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Feed Port" --nocancel --inputbox "\nChange only if you were assigned a custom feed port.\nUnless you have been told otherwise, leave this set to 4091." 10 78 "4091" 3>&1 1>&2 2>&3)


whiptail --backtitle "$BACKTITLETEXT" --title "$BACKTITLETEXT" --yesno "We are now ready to begin setting up your receiver to feed FlightMate.\n\nDo you wish to proceed?" 9 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    exit 0
fi

## BEGIN SETUP

{

    # Make a log directory if it does not already exist.
    if [ ! -d "$LOGDIRECTORY" ]; then
        mkdir $LOGDIRECTORY
    fi
    LOGFILE="$LOGDIRECTORY/image_setup-$(date +%F_%R)"
    touch $LOGFILE

    echo 4
    sleep 0.25
    # SETUP NETCAT TO SEND DUMP1090 DATA TO FlightMate

    # Create the netcat maintenance script.
    tee flightmate-netcat_maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
    #/bin/nc 127.0.0.1 30005 | /bin/nc in.flightmate.nz $RECEIVERPORT
    /usr/bin/socat -u TCP:127.0.0.1:30005 TCP:in.flightmate.nz:$RECEIVERPORT
  done
EOF

    echo 76
    sleep 0.25

    # Set permissions on the file flightmate-netcat_maint.sh.
    chmod +x flightmate-netcat_maint.sh >> $LOGFILE

    echo 82
    sleep 0.25

    # Add a line to execute the netcat maintenance script to /etc/rc.local so it is started after each reboot if one does not already exist.
    if ! grep -Fxq "$PWD/flightmate-netcat_maint.sh &" /etc/rc.local; then
        lnum=($(sed -n '/exit 0/=' /etc/rc.local))
        ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $PWD/flightmate-netcat_maint.sh &\n" /etc/rc.local >> $LOGFILE
    fi

    echo 88
    sleep 0.25

    # Kill any currently running instances of the flightmate-netcat_maint.sh script.
    PIDS=`ps -efww | grep -w "flightmate-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        sudo kill $PIDS >> $LOGFILE
        sudo kill -9 $PIDS >> $LOGFILE
    fi

    echo 94
    sleep 0.25

    # Execute the netcat maintenance script.
    sudo nohup $PWD/flightmate-netcat_maint.sh > /dev/null 2>&1 & >> $LOGFILE
    echo 100
    sleep 0.25

} | whiptail --backtitle "$BACKTITLETEXT" --title "Setting Up FlightMate Feed"  --gauge "\nSetting up your receiver to feed FlightMate.\nThe setup process may take awhile to complete..." 8 60 0

## SETUP COMPLETE

# Display the thank you message box.
whiptail --title "FlightMate Setup Script" --msgbox "\nSetup is now complete.\n\nYour feeder should now be feeding data to FlightMate.\nThanks again for choosing to share your data with FlightMate!\n\nIf you have questions or encountered any issues while using this script feel free to post them to one of the following places.\n\\nhttp://FlightMate.nz/" 17 73

exit 0
