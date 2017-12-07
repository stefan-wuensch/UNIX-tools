#!/usr/bin/env bash

# vpn-connect.sh
#
# by Stefan Wuensch, 2017-12-06
#
# Automated connection to Cisco VPN using AnyConnect client CLI, reading credential / login script
# from Mac OS Keychain where it is stored securely. All handling of secrets is done in memory
# and pipes for security; no temp files!
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
# 	- Cisco AnyConnect VPN client software
# 	- a Mac Keychain item (Password or Secure Note) in the correct format - see below
# 
# 
# 
########################################################################################################################
# Keychain item format details
# 
# 
# Secure Note Item:
# 	- must be multiple lines, in this order: [ username#realm, password, blank line, "y" ]
# 
# Secure Note Example:
#-------------------------------------------------------
# john_harvard@harvard.edu#vpnrealm
# p4ssw0rd
# 
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




########################################################################################################################
# Optional: Customize these variables to your own default, if desired.
vpn_host="vpn.harvard.edu"			# Set a default - replaced by optional arg from command line
keychain_script_name="Stefan VPN Login Script" 	# Same - set a default for if there's no arg
########################################################################################################################


# Set safe path
PATH=/usr/bin:/opt/cisco/anyconnect/bin:/bin
export PATH


########################################################################################################################
usage() {
	echo -e "\nUsage: $0 [ -v ] [ -h ] [ -n \"name of login script in Keychain\" ] [ -d \"name of VPN device\" ]"
	echo -e "\nWARNING: USING \"-v\" WILL DISPLAY CREDENTIALS ON YOUR SCREEN. Do not use \"-v\" in a non-private environment.\n"
}


########################################################################################################################
### Function: print '.' while waiting for other things to happen
### Returns PID of child looping process to STDOUT so it can be killed later!

start_dots() {
	while true ; do printf "." ; sleep 1 ; done 1>&2 &
	childPID=$!
	echo $childPID
}


########################################################################################################################
### Function: Stop the dots!

stop_dots() {
	kill $1
	trap  0 2 3 15
	echo " Done."
}

########################################################################################################################



# Check for all the needed Mac commands. If any one is not found, bail out!
# Since this script is all about getting the VPN credentials from Mac OS
# Keychain, there's no point in proceeding if we're not running on a Mac!!
for command in security xxd plutil xmllint vpn open ; do
	if ! which ${command} >/dev/null 2>&1 ; then
		>&2 echo "Error: Can't find required Mac OS command \"${command}\" in paths \"${PATH}\" - are you running this on a Mac, with Cisco AnyConnect client installed?"
		exit 1
	fi
done

# Test first arg for a leading dash. If ARGV[1] doesn't start with a dash, it's invalid.
if ! echo -- "${1}" | egrep -q -- '^-' ; then
	>&2 echo -e "\nError: \"${1}\" is not a valid option."
	>&2 usage
	exit 1
fi


# Take the args if they are present
while getopts ":vhn:d:" theOption ; do
	case $theOption in
		v)	echo "Turning on verbose mode. YOUR CREDENTIALS MIGHT BE DISPLAYED."
			echo "Hit ^C in the next 5 seconds if this is not what you want."
			sleep 5
			verbose="YES" ;;

		h)	>&2 usage ; exit 0 ;;

		n)	keychain_script_name="${OPTARG}" ;;

		d)	vpn_host="${OPTARG}" ;;

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
	echo "Can't find \"${keychain_script_name}\" in your Mac OS Keychain. Exiting."
	exit 1
fi


# Figure out if the keychain item was a Password or a Secure Note.
# If it's a Password we have to evaluate the '\n' to get newlines.
# If it's a Secure Note, it's going to be an encoded PLIST in XML which we'll have to decode!
if /bin/echo ${raw_keychain} | grep -q '\\n' ; then

	# Password item, so we use 'echo -e' to evaluate the '\n' into newlines
	login_script=$( echo -e "${raw_keychain}" )

else
	# Secure Note, so we extract it.
	login_script=$( echo ${raw_keychain} |
		xxd -r -p |				# Decode the hex
		plutil -extract "NOTE" xml1 -o - - |	# Get the note part of the PLIST
		xmllint --xpath '//string/text()' -	# Grab only the "string" element of the XML
	)
fi

# Finally, we should now have everything we need!


# If the regular Mac client app is running, it prevents the CLI from connecting.
# Quit the UI app if it's found.
ui_pid=$( pgrep "Cisco AnyConnect Secure Mobility Client" ) && kill $ui_pid


# Making an attempt to limit the run-away looping of a failed "script" connection...
# The AnyConnect client (version 4.5.02033 as of 2017-12-07) appears to be unable to
# gracefully handle an authentication failure when "script" input is coming in on STDIN.
# It appears to loop forever on error - but the simplest way to handle it is just to
# tell the user to manually abort and try again. (The output from the failed connection process
# is horribly ugly and would be a nightmare to try and parse.)

echo -e "\nIf the connection does not complete after 20 to 30 seconds, hit Control-C (^C) to abort."
echo "After repeated failures, check your credentials \"script\" in the Keychain, and try"
echo "running this again with \"-v\" flag."
echo -e "\nIf your credentials script from the Keychain works, the next thing you should get is the prompt from Duo."
printf "\nConnecting to ${vpn_host}..."


# Only show output from the connection if '-v' arg was given.
if [[ -n "${verbose}" ]] && [[ "${verbose}" == "YES" ]] ; then
	echo "${login_script}" | vpn -s connect "${vpn_host}"
	exit_state=$?
else
	dotsPID=$( start_dots )
	trap 'stop_dots $dotsPID' 0 2 3 15
	echo "${login_script}" | vpn -s connect "${vpn_host}" >/dev/null 2>&1
	exit_state=$?
fi

[[ -n "${dotsPID}" ]] && stop_dots $dotsPID

if [[ ${exit_state} -ne 0 ]] ; then
	echo "Problem making VPN connection. Check your keychain item, and try running this with \"-v\"."
fi


# Display the state of the connection - which should be "state: Connected" from the "vpn" command.
if vpn state | grep -q "state: Connected" ; then
	echo "Connected!"
else
	echo "VPN appears not connected when running command \"vpn state\". Something may have gone wrong. Try repeating with \"-v\"."
	exit 1
fi

# Extra bonus - start the UI app hidden ("-j") and in background ("-g") so the menubar item shows up.
# Also it makes it easy to disconnect the VPN connection, because to do that once the UI app is running
# you simply quit it. Quitting the app terminates the connection even if it was started from CLI.
open -j -g "/Applications/Cisco/Cisco AnyConnect Secure Mobility Client.app"
echo "Note: use the usual Mac OS VPN app to disconnect simply by quitting it, or type \"vpn disconnect\"."

