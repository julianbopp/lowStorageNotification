#!/bin/zsh
#set -x 

# deferralsExample.sh
# v.1.0

# Written by Trevor Sysock @BigMacAdmin

# Please see the software license in the associated GitHub repo: 
# https://github.com/SecondSonConsulting/swiftDialogExamples

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# Overview:
# This script is meant to be an example framework for how to prompt users
# to complete an action and offer deferrals.

# The concept here is that you can call a script repeatedly on whatever
# schedule suits your needs. The script will exit clean and quiet if a 
# deferral is active, or if the "check_the_things" function decides no action
# is needed.

######################
#   How to Configure #
######################

# All time/date calculations are given in seconds

# Admins will want to at least configure everything within the "User Configuration Variables"
# and the "User Configuration Functions" section of the script.

#########
# Tools #
#########

# Path to SwiftDialog
dialogPath="/usr/local/bin/dialog"

# Path to PlistBuddy. We'll use this to write to our config file
pBuddy="/usr/libexec/PlistBuddy"

################################
# User Configuration Variables #
################################

# How long until a deferral expires? Value in seconds. Set this low for testing.
deferralDuration="10"

# How many deferrals until you no longer offer them? In this example, the DeferralCount value is reset
# when the "do_the_things" action completes successfully.
deferralMaximum="3"

# Deadline Date. This is a unix epoch time value. 
# To get this value converted from a human readable date you can use a "unix epoch time" 
# calculator like this one: https://www.epochconverter.com/
# If the script runs after this deadline date, no deferrals will be offered.
# Leave empty if you don't want to use this feature
deadlineDate=""

# Full file path to your configuration profile.
# For this example, we'll just stay in the current working directory.
# 
# You will want to consider "Is this a root daemon or a user agent?" as well as
# whether you want separate deferral files for multiple users or one file
# for the system.
deferralPlist="com.bigmacadmin.deferralexample.plist"

#################################
# User Configuration Functions  #
#################################

function check_the_things()
{
    # Use this if you need to add a check to see if the purpose of this script needs to be actioned on.
    # For example, if you wanted this script to take action when the "uptime" of a device has exceeded a 
    # certain value, here is where you would put that check.
    # If "check the things" exits true, then the script continues on. If it exits false (non-zero exit/return code) then
    # the thing doesn't need to happen and the script exits.
    # You can omit this function entirely if you want the script to take action always.

    # For our example, we'll use "If true" which always returns true (or exit code zero) Change to "if false" for 
    # testing the opposite.
    

    cd "$(dirname "$0")"
    freespace=$(./freespace)

    # Specify space bound for aggresive popup
    aggresive=$((700 * 1000000000))
    # Specify space bound for passive notification in notification center
    passive=$((800 * 1000000000))


    log_message $freespace
    if [ "$freespace" -lt "$aggresive" ]; then
        log_message "Conditions for aggresive measures met. Script will continue"
    elif [ "$freespace" -lt "$passive" ]; then
        log_message "Conditions for passive measures met. Display alert in notification center."
        passive_notification
    else 
        cleanup_and_exit 0 "Popup is not needed. Exiting"
    fi
}

function passive_notification()
{
    # https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/DisplayNotifications.html
    # Is user using en or de locale? Use english as default
    userlang=$(defaults read -g AppleLocale) 
    userlang=${userlang:0:2}

    # Display popup with title and description
    if [ "$userlang" = "de" ]; then
        osascript -e 'display notification "Möglicherweise bald nicht genug Speicher für wichtige Systemupdates" with title "Speicher fast voll"'
    else
        # english version
        osascript -e 'display notification "Soon there might be not enough space for important system updates" with title "Space is running low"'
    fi
        cleanup_and_exit 0 "Popup is not needed. Exiting"
}


function do_the_things()
{
    # This is where you put the actual action you want the script to take. This is executed when the user consents by 
    # clicking "OK" on the Dialog window

    # Get macOS version installed
    mac_version=$(sw_vers -productVersion | awk '{print int($NF)}')
        
    # Do different actions based on macOS version
    if [ "$mac_version" -eq "13" ]; then
        log_message "Running macOS Ventura, opening system settings" 
        open "x-apple.systempreferences:com.apple.settings.Storage"
    else
        log_message "Running macOS Monterey or older, opening Storage Management.app"
        open -a "Storage Management"
    fi

    # Since we did the things, we'll set the deferral count back to 0.
    # You may want to move this elsewhere in the script, or do things differently. For our example, it makes sense
    # to put this here.
    $pBuddy -c "Set DeferralCount 0" $deferralPlist
}

function dialog_prompt_with_deferral()
{
    # This is where we define the dialog window options asking the user if they want to do the thing.
    
    # Is user using en or de locale? Use english as default
    userlang=$(defaults read -g AppleLocale) 
    userlang=${userlang:0:2}
    userlang=de

    if [ "$userlang" = "de" ]; then
        log_message "Using de locale."
        "$dialogPath" \
        --icon logo.png \
        --title "Dein Festplattenspeicher ist fast voll!" \
        --message "Bitte gebe etwas Speicher frei. Wenn du auf 'OK' drückst öffnen sich deine Speichereinstellungen." \
        --icon "SF=bolt.circle color1=pink color2=blue" \
        --button2text "Nicht jetzt" \
        --infobuttontext "Kontaktiere IT Support" \
        --infobuttonaction "https://its.unibas.ch/de/beratung-hilfe/service-desk/"
    else 
        log_message "Using en locale."
        "$dialogPath" \
        --icon logo.png
        --title "You're running out of space!" \
        --message "Please delete some files to make space for important updates. Clicking 'OK' will open your storage settings." \
        --icon "SF=bolt.circle color1=pink color2=blue" \
        --button2text "Not Now" \
        --infobuttontext "Contact IT Support" \
        --infobuttonaction "https://its.unibas.ch/en/advice-and-help/service-desk/"
    fi
}

function dialog_prompt_no_deferral()
{
    # This is where we define the dialog window options when we're no longer offering deferrals. "Aggressive mode" 
    # so to speak.
    #"$dialogPath" \
    #--title "We must now do the thing" \
    #--message "Hey, we can't put off the thing any longer. It's going to be done now." \
    #--icon "SF=bolt.circle color1=pink color2=blue" \
    "$dialogPath" \
    --title "You're running out of space!" \
    --message "Delete some files to make space for important updates. Closing this window will open your storage settings." \
    --icon "SF=bolt.circle color1=pink color2=blue" \
    --infobuttontext "Contact IT Support" \
    --infobuttonaction "mailto:its-support@unibas.ch?subject=Storage%20is%20running%20low"
}

##################
# Core Functions #
##################

# Send a message to the log. For the example it just echos to standard out
function log_message()
{
    echo "$(date): $@"
}

# This function exits the script. Takes two arguments. Argument 1 is the exit code 
# and argument 2 is an optional log message
# Example: cleanup_and_exit 0 "We are done, no problems found."
function cleanup_and_exit()
{
    # If you have temp folders/files that you want to delete as this script exits, this is the place to add that
    log_message "${2}"
    exit "${1}"
}

function verify_config_file()
{
    # Check if we can write to the configuration file by writing something then deleting it.
    if $pBuddy -c "Add Verification string Success" "$deferralPlist"  > /dev/null 2>&1; then
        $pBuddy -c "Delete Verification string Success" "$deferralPlist" > /dev/null 2>&1
    else
        # This should only happen if there's a permissions problem or if the deferralPlist value wasn't defined
        cleanup_and_exit 1 "ERROR: Cannot write to the deferral file: $deferralPlist"
    fi

    # See below for what this is doing
    verify_deferral_value "ActiveDeferral"
    verify_deferral_value "DeferralCount"

}

function verify_deferral_value()
{
    # Takes an argument to determine if the value exists in the deferral plist file.
    # If the value doesn't exist, it writes a 0 to that value as an integer
    # We always want some value in there so that PlistBuddy doesn't throw errors 
    # when trying to read data later
    if ! $pBuddy -c "Print :$1" "$deferralPlist"  > /dev/null 2>&1; then
        $pBuddy -c "Add :$1 integer 0" "$deferralPlist"  > /dev/null 2>&1
    fi

}

function check_for_active_deferral()
{
    # This function checks if there is an active deferral present. If there is, then it exits quietly.

    # Get the current deferral value. This will be 0 if there is no active deferral
    currentDeferral=$($pBuddy -c "Print :ActiveDeferral" "$deferralPlist")

    # If unixEpochTime is less than the current deferral time, it means there is an active deferral and we exit
    if [ "$unixEpochTime" -lt "$currentDeferral" ]; then
        cleanup_and_exit 0 "Active deferral found. Exiting"
    else
        log_message "No active deferral."
        # We'll delete the "human readable" deferral date value, if it exists.
        $pBuddy -c "Delete :HumanReadableDeferralDate" "$deferralPlist"  > /dev/null 2>&1
    fi
}


function execute_deferral()
{
    # This is where we define what happens when the user chooses to defer

    # Setting deferral variables
    # Set the date the deferral will expire. If the script runs again before this date, it exits quietly without
    # bothering the user.
    deferralDateSeconds=$((unixEpochTime + deferralDuration ))
    # This is a human readable date format of the deferral date. This serves no function except to make it easy
    # to tell when the deferral will expire.
    deferralDateReadable=$(date -j -f %s $deferralDateSeconds)
    # Increase the number of deferrals by 1. This gets checked against the maximum allowed deferrals next time
    # the script runs.
    deferralCount=$(( deferralCount + 1 ))

    # Writing deferral values to the plist
    $pBuddy -c "Set ActiveDeferral $deferralDateSeconds" $deferralPlist
    $pBuddy -c "Set DeferralCount $deferralCount" $deferralPlist
    $pBuddy -c "Add :HumanReadableDeferralDate string $deferralDateReadable" "$deferralPlist"  > /dev/null 2>&1

    # Deferral has been processed. Exit cleanly.
    cleanup_and_exit 0 "User chose deferral $deferralCount of $deferralMaximum. Deferral date is $deferralDateReadable"
}

######################
# Script Starts Here #
######################

verify_config_file

# Get the current date in seconds (unix epoc time)
unixEpochTime=$(date +%s)

check_for_active_deferral

check_the_things

# Get the current deferral count
deferralCount=$($pBuddy -c "Print :DeferralCount" $deferralPlist)


# This next block does the logic to determine if we're going to allow deferrals or not

# Check if Deadline has been set, and if we are now past it
if [ ! -z "$deadlineDate" ] && [ "$deadlineDate" -lt "$unixEpochTime" ]; then
    # Deadline has been configured, and we're past it.
    allowDeferral="false"
# Check if the number of deferrals used is greater than the maximum allowed
elif [ "$deferralCount" -ge "$deferralMaximum" ]; then
    allowDeferral="false"
else
    # Deadline isn't past and the deferral count hasn't been exceeded, so we'll allow deferrals.
    allowDeferral="true"
fi

# For the sake of this example the logic below is simplified in the following ways:
# - It assumes that exiting 0 is consent to do the thing
# - It assumes exiting Dialog with anything other than 0 is a deferral (so CMD+Q, or if they `killall Dialog` 
#       it will process a deferral)
# - If we're not offering a deferral, then "do_the_things" gets executed regardless of the dialog exit code
# If you'd like to do things differently, you can capture the exit code of the "dialog_prompt_with_deferral" function
# and do an if/elif/else or case statement to take action based on that exit code.

# If we're allowing deferrals, then
if [ "$allowDeferral" = "true" ]; then
    # Prompt the user to ask for consent. If it exits 0, they clicked OK and we'll do the things
    if dialog_prompt_with_deferral; then
        # Here is where the actual things we want to do get executed
        do_the_things
        # Capture the exit code of our things, so we can exit the script with the same exit code
        thingsExitCode=$?
        cleanup_and_exit $thingsExitCode "Things were done. Exit code: $thingsExitCode"
    else
        execute_deferral
    fi
else
    # We are NOT allowing deferrals, so we'll continue with or without user consent
    dialog_prompt_no_deferral
    do_the_things
    # Capture the exit code of our things, so we can exit the script with the same exit code
    thingsExitCode=$?
    cleanup_and_exit $thingsExitCode "Things were done. Exit code: $thingsExitCode"
fi
