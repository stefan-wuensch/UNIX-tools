#!/usr/bin/env bash
# shellcheck disable=SC1117

########################################################################################################################
# vpn-connect.sh
#
# by Stefan Wuensch, 2017-12-06
#
# Automated connection to Cisco VPN using AnyConnect client CLI, reading credential / login script
# from Mac OS Keychain where it is stored securely. All handling of secrets is done in memory
# and pipes for security; no temp files!
#
# Because you can have multiple VPN login credentials stored safely in your Keychain, if you
# use more than one VPN realm this script makes it much faster to connect. Less typing! Quicker!
# Even if you only ever use one VPN realm this script eliminates the need for mouse actions
# and speeds up your getting on the VPN.
#
#
# Usage:
# 	vpn-connect.sh [ -v ] [ -h ] [ -n "name of login script in Keychain" ] [ -d "name of VPN device" ]
#
# WARNING: USING "-v" WILL DISPLAY CREDENTIALS ON YOUR SCREEN. Do not use "-v" in a non-private environment.
#
#
# Requirements:
#	- running this on a Mac OS X machine
# 	- Cisco AnyConnect VPN client software (including /opt/cisco/anyconnect/bin/vpn command)
# 	- a Mac Keychain item (Password or Secure Note) in the correct format - see below
# 	- the item(s) should be in your default Keychain, which is indicated in boldface in the keychain list
#
#
# The Keychain Access Mac app is used to create / modify / delete Keychain Items.
# It is found at Applications --> Utilities --> Keychain Access
# From the command line: "open /Applications/Utilities/Keychain Access.app"
#
# Keychain notes:
# 	https://support.apple.com/kb/PH20093	- Keychain Access overview
# 	https://support.apple.com/kb/PH20119	- Secure Notes in Keychain
# 	https://support.apple.com/kb/PH20097	- Keychain troubleshooting
# 	https://support.apple.com/kb/PH20094	- Keychain and login password
#
#
#
########################################################################################################################
# Keychain item format details
#
# Each Keychain Item VPN login "script" must contain four elements for Harvard:
# 	1) your Harvard Key email address
# 	2) your Harvard Key password
# 	3) a blank line (which forces Duo Push) or One-Time-Password (OTP)
# 	4) the letter "y" (to accept the connection terms)
#
# *** You can use either the "Secure Note Item" format or the "Password Item" format. ***
# 	You don't have to use both. You can pick the format that is easier for you.
#
#
# Secure Note Item:
# 	- must be multiple lines, in this order: [ username#realm, password, blank line, "y" ]
#
# Secure Note Item Example:
#-------------------------------------------------------
# john_harvard@harvard.edu#vpnrealm
# p4ssw0rd
# OTP_VALUE
# y
#-------------------------------------------------------
#
#
# Password Item:
# 	- must be a SINGLE line with "\n" separating each element
# 	- elements are the same as, and in the same order as, the Secure Note format
#
# Password Item Example:
#-------------------------------------------------------
# john_harvard@harvard.edu#vpnrealm\np4ssw0rd\n\ny\n
#-------------------------------------------------------
#
# Note that there are two "\n" back-to-back in the Password Item, to represent the
# end of the password line and the blank line.
#
# Also note that if your Harvard Key password contains a backslash followed by a lower-case "n"
# as in "\n" then you CANNOT use the Password Item format because that is the line delimiter.
# You will HAVE TO use the Secure Note format in that case.
#
#
########################################################################################################################
#
# Notes:
# 	- in Mac OS X 10.13.1, if you rename a Secure Note in the Keychain you might not ever be able to access
# 		it again from the CLI!! It appears that the 'security' command can only read the "Service" name
# 		of a Secure Note, but when you rename an existing one the "Service" name DOES NOT change!
# 		If you want to change the name of an existing Secure Note and still use it with this script
# 		(or any other script calling "/usr/bin/security") you may have to delete and re-create the item.
#
#
# Shout-outs:
# https://superuser.com/questions/1153273/access-key-pairs-in-a-macos-keychain-from-the-commandline
# https://superuser.com/questions/649614/connect-using-anyconnect-from-command-line
#
# Checked with https://www.shellcheck.net/
#
# Note for people outside Harvard using this: If you don't use two-factor auth from Duo for your Cisco VPN,
# then the blank line in the connection script probably should be removed. I'm not sure about that, since
# the only environment where I can test this script requires 2FA with Duo. Caveat emptor.
#
########################################################################################################################
# MIT License
#
# Copyright (c) 2020 Stefan Wuensch
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
########################################################################################################################





########################################################################################################################
# Optional: Customize these variables to your own default, if desired.
vpn_host="vpn.harvard.edu"			# Set a default - replaced by optional arg from command line "-d"
keychain_script_name="Stefan VPN Login Script" 	# Same - set a default for if there's no arg "-n" given
########################################################################################################################


# Other default variables for operation. You should not need to change these!
otp_placeholder_string="OTP_VALUE"		# Defines the string in the login script to be replaced with OTP value
token_value=""					# Set to null, so if no OTP is given in args the default will be push


# Set safe path
PATH=/usr/bin:/opt/cisco/anyconnect/bin:/bin
export PATH


########################################################################################################################
usage() {
	echo -e "\nUsage: ${0} [ -v ] [ -h ] [ -t OTP_value ][ -n \"name of login script in Keychain\" ] [ -d \"name of VPN device\" ]"
	echo -e "\nDefault values:"
	echo -e "Keychain item default name: \"${keychain_script_name}\"  (edit this script to change)"
	echo -e "VPN target default name:    \"${vpn_host}\"  (edit this script to change)"
	echo -e "\nFor full usage and requirements, read the comments in this script ${0}"
	echo -e "\nWARNING: USING \"-v\" WILL DISPLAY CREDENTIALS ON YOUR SCREEN. Do not use \"-v\" in a non-private environment.\n"
}


########################################################################################################################
### Function: print '.' while waiting for other things to happen
### Returns PID of child looping process to STDOUT so it can be killed later!

start_dots() {
	while true ; do printf "." ; sleep 1 ; done 1>&2 &
	childPID=$!
	echo "${childPID}"
}


########################################################################################################################
### Function: Stop the dots!

stop_dots() {
	kill "${1}"
	trap  0 2 3 15
	echo " Done."
}

########################################################################################################################



# Check for all the needed Mac commands. If any one is not found, bail out!
# Since this script is all about getting the VPN credentials from Mac OS
# Keychain, there's no point in proceeding if we're not running on a Mac!!
for command in security xxd plutil xmllint vpn open ; do
	if ! which "${command}" >/dev/null 2>&1 ; then
		>&2 echo "Error: Can't find required Mac OS command \"${command}\" in paths \"${PATH}\" - are you running this on a Mac, with Cisco AnyConnect client installed?"
		exit 1
	fi
done


# Test first arg for a leading dash. If ARGV[1] doesn't start with a dash, it's invalid.
if [[ -n "${1}" ]] ; then	# Only if it's set
	if ! printf "%s\n" "${1}" | grep -E -q -- '^-.' ; then	# use printf for portability since '-n' is a valid arg to 'echo'
		>&2 echo -e "\nError: \"${1}\" is not a valid option."
		>&2 usage
		exit 1
	fi
fi

# Take the args if they are present
while getopts ":vhn:d:t:" theOption ; do
	case $theOption in
		v)	echo -e "\nTurning on verbose mode. YOUR CREDENTIALS MIGHT BE DISPLAYED."
			echo "Hit ^C in the next 5 seconds if this is not what you want."
			sleep 5
			verbose="YES" ;;

		h)	>&2 usage ; exit 0 ;;

		n)	keychain_script_name="${OPTARG}" ;;

		d)	vpn_host="${OPTARG}" ;;

		t)	token_value="${OPTARG}" ;;

		:)	>&2 echo -e "\nError: \"-${OPTARG}\" needs a value."
			>&2 usage ; exit 1 ;;

		*)	>&2 echo -e "\nError: Unknown option \"-${OPTARG}\""
			>&2 usage ; exit 1 ;;
	esac
done

# Safety check the existence critical variables
[[ -z "${keychain_script_name}" ]] && 	{ >&2 usage ; exit 1 ; }
[[ -z "${vpn_host}" ]] && 		{ >&2 usage ; exit 1 ; }


# Check for that Keychain item name while assigning. Bail out if it's not there.
if ! raw_keychain=$( security find-generic-password -s "${keychain_script_name}" -w 2>&1 ) ; then
	>&2 echo -e "\nError: Can't find \"${keychain_script_name}\" in your Mac OS Keychain. Exiting."
	exit 1
fi


# Figure out if the keychain item was a Password or a Secure Note.
# If it's a Password we have to evaluate the '\n' to get newlines.
# If it's a Secure Note, it's going to be an encoded PLIST in XML which we'll have to decode!
if /bin/echo "${raw_keychain}" | grep -q '\\n' ; then

	# Password item, so we use 'echo -e' to evaluate the '\n' into newlines
	login_script=$( echo -e "${raw_keychain}" )
	# Confirm that we're using a Password item, which one, and the VPN target name
	echo -e "\nUsing login script from Keychain Password Item \"${keychain_script_name}\" to connect to \"${vpn_host}\"..."

else
	# Secure Note, so we extract it.
	login_script=$( echo "${raw_keychain}" |
		xxd -r -p 2>/dev/null |					# Decode the hex
		plutil -extract "NOTE" xml1 -o - - 2>/dev/null |	# Get the note part of the PLIST
		xmllint --xpath '//string/text()' - 2>/dev/null 	# Grab only the "string" element of the XML
	)
	# Confirm that we're using a Secure Note item, which one, and the VPN target name
	echo -e "\nUsing login script from Keychain Secure Note Item \"${keychain_script_name}\" to connect to \"${vpn_host}\"..."
fi

# Now replace the OTP place-holder in the login script with the actual OTP, which is null if not specified.
# The default null value for the OTP will cause Duo push - at least in our Harvard environment.
login_script=$( echo "${login_script}" | sed -e "s/${otp_placeholder_string}/${token_value}/" )


# Finally, we should now have everything we need!


# Check the state of the connection. If we're already connected, ask what to do!
if vpn state | grep -q "state: Connected" ; then
	echo -e "\n*** VPN connection appears to be already established! ***"
	echo "\"/opt/cisco/anyconnect/bin/vpn state\" reports \"state: Connected\""
	vpn stats | grep -E 'Client Address \(IPv4\)|Profile Name' 	# Display the client-side IP address and realm
	printf "Do you want to end the current connection and continue with a new connection? [Y/n] "
	read -r answer
	case ${answer} in
		n*)	echo "OK - exiting this script to preserve your existing connection."
			# See end of this script for details on this "open" call. Opening it here since we were told to stay connected.
			open -j -g "/Applications/Cisco/Cisco AnyConnect Secure Mobility Client.app"
			exit 0 ;;
		*)	echo "OK - terminating your existing connection to set up a new one."
			vpn disco | grep '>>'	# Short for "disconnect" but I have to use the cool abbreviation!! :-)
						# The 'grep' is to show just the useful bits.
			sleep 1 ;;		# Just in case the subsystem needs a sec.
	esac
fi


# If the regular Mac client app is running, it prevents the CLI from connecting.
# Quit the UI app if it's found. We'll start it again at the end.
# (It's handy to have the menu-bar-item showing the status.)
ui_pid=$( pgrep "Cisco AnyConnect Secure Mobility Client" ) && kill "${ui_pid}"


# Making an attempt to limit the run-away looping of a failed "script" connection...
# The AnyConnect client (version 4.5.02033 as of 2017-12-07) appears to be unable to
# gracefully handle an authentication failure when "script" input is coming in on STDIN.
# It appears to loop forever on error - but the simplest way to handle it is just to
# tell the user to manually abort and try again. (The output from the failed connection process
# is horribly ugly and would be a nightmare to try and parse.)

echo -e "\nIf the connection does not complete after 20 to 30 seconds, hit Control-C (^C) to abort."
echo "After repeated failures, check your credentials \"script\" in the Keychain, and try"
echo "running this again with \"-v\" flag."
echo -e "\nIf your credentials script from the Keychain works, the next thing you should get is the prompt from Duo on your mobile device."
printf "\nConnecting to %s..." "${vpn_host}"


# Only show output from the connection if '-v' arg was given.
if [[ -n "${verbose}" ]] && [[ "${verbose}" == "YES" ]] ; then
	echo -e "\nLogin script is:\n${login_script}"
	echo "${login_script}" | vpn -s connect "${vpn_host}"
	exit_state=$?
else
	dotsPID=$( start_dots )
	trap 'stop_dots $dotsPID' 0 2 3 15
	echo "${login_script}" | vpn -s connect "${vpn_host}" >/dev/null 2>&1
	exit_state=$?
fi

[[ -n "${dotsPID}" ]] && stop_dots "${dotsPID}"

if [[ ${exit_state} -ne 0 ]] ; then
	echo "Problem making VPN connection. Check your keychain item, and try running this with \"-v\"."
fi

# Wait for a moment for the connection to stabilze. I've seen a *very* rare case where
# running "vpn state" will hang if it's too soon after the "vpn connect" is run. I can't
# reproduce it deliberately, so this is just in case it helps.
sleep 2

# Display the state of the connection - which should be "state: Connected" from the "vpn" command.
if vpn state | grep -q "state: Connected" ; then
	echo "Connected!"
	vpn stats | grep -E 'Client Address \(IPv4\)|Profile Name' 	# Display the client-side IP address and realm
else
	>&2 echo -e "\nVPN appears not connected when running command \"/opt/cisco/anyconnect/bin/vpn state\". Something may have gone wrong. Try repeating with \"-v\"."
	exit 1
fi

# Extra bonus - start the UI app hidden ("-j") and in background ("-g") so the menubar item shows up.
# Also it makes it easy to disconnect the VPN connection, because to do that once the UI app is running
# you simply quit it. Quitting the app terminates the connection even if it was started from CLI.
open -j -g "/Applications/Cisco/Cisco AnyConnect Secure Mobility Client.app"
echo "Note: use the usual Mac OS VPN app to disconnect simply by quitting the app, or type \"/opt/cisco/anyconnect/bin/vpn disconnect\"."

