#!/usr/bin/env bash


# netrc-osxkeychain.sh
# by Stefan Wuensch, 2017-07-14

# This script allows you to securely store authentication data in
# the Keychain which can then be used by UNIX commands like "curl".
# 
# This script retrieves a server-name/user-name/password triplet
# from an item in the Mac OS Keychain, and outputs those in a 
# .netrc file format. You can then use Process Substitution with commands
# like "curl" to perform an authenticated transaction with maximum
# local security. (Of course you have to make sure your curl connection
# is secured over the network - like via HTTPS. The job of this script
# is to allow secure storage in the Keychain, and then to present the
# secrets in a way which can be hidden from arg-snooping with 'ps'.)
# Why is simply putting passwords in .netrc not good enough? That file
# is plaintext!! Much better to use the Mac OS Keychain.

# When you initially create a new Keychain Item using the Keychain Access app,
# you are only prompted for:
# 1) Keychain Item Name
# 2) Account Name
# 3) Password
# The "Kind" and "Where" fields (see below) are auto-filled by the Keychain Access app.
# Also, in order to enter the "Comments" (used in this script as the server name)
# you have to find the new item in the list of all Keychain items, double-click
# it (or Command-I "Get Info") and then fill in the Comments after creating it.

# Example Keychain Item (what you see in Keychain Access app after creating it):
# Name:		Some Keychain Item
# Kind:		application password
# Account:	fred
# Where:	Some Keychain Item
# Comments:	some-server.domain.tld

# Usage example:
# curl --netrc-file <( netrc-osxkeychain.sh "Some Keychain Item" ) https://some-server.domain.tld/blah/

# Example format of .netrc file using example values:
# (https://ec.haxx.se/usingcurl-netrc.html)
############################################
# machine	some-server.domain.tld
# login		fred
# password	ABCXYZ
############################################
# As noted above, saving passwords in a .netrc file is NOT GOOD because they will
# not be protected other than by filesystem security. By using the Mac OS Keychain
# and this script, the decrypted secrets are only ever in memory.

# Note that the execution of this script is being done in Process Substitution
# http://tldp.org/LDP/abs/html/process-sub.html
# because that's the only way to protect the authentication credentials from
# being exposed on the command line for anyone to snoop using 'ps'.


# IMPORTANT:
# In the Keychain Item there MUST be a "Comments" entry which has a value
# EXACTLY the same as the server name FQDN you are using in the curl command.
# That is the only way that the curl command will utilize the .netrc data
# that you are sending it from this script, because this script has to output
# a .netrc "machine" value. 
# (Because the .netrc file can be used by multiple applications - not just curl -
# and because you can have multiple entries in it, we can't just expect that
# "login" and "password" fields are enough. The "machine" field also has to be
# there, and it HAS TO match the FQDN of the URI **exactly**. The "Comments"
# attribute of the Keychain Item is a handy way to do this, and it's required
# for this script to work.


export PATH=/bin:/usr/bin


usage() {
	>&2 echo "Usage: ${0} name-of-keychain-item"
}


# Need exactly one arg, the Mac OS X Keychain Item name.
[[ -z "${1}" ]] && { usage; exit 1 ; }
[[ $# -ne 1 ]]  && { usage; exit 1 ; }

keychainItem="${1}"

# Disclaimer: This current implementation is making *multiple* calls
# to 'security find-generic-password' (which is not optimal) but it's
# in order to avoid having to capture a non-standard output format
# and then parse it in ways that would be ugly. By making multiple
# calls to 'security find-generic-password' it makes the code more
# understandable and probably more reliable.


# Try getting the password from the Keychain item for the given name. If it's not there, we can't proceed!
if ! password=$( security find-generic-password -s "${keychainItem}" -w 2>/dev/null ) ; then
	>&2 echo "Can't find the item \"${keychainItem}\" in your Mac Keychain!"
	exit 2
fi

# Dummy-check that we actually did get a password value into the variable.
# This is belt-and-suspenders, but an easy check.
[[ -z "${password}" ]] && { >&2 echo "Did not actually get a value back for the password! Bailing out." ; exit 2 ; }


# Now we have to try and get the account name from the non-standard output of the 'security' command.
# This is annoying, but it's worth it so that we don't have to make the user of this script
# supply the account name as another command argument. If we only have one arg to this script
# then we don't have to worry about silliness with 'getopts' or position-specific args... we
# only have one arg and that's nice and simple.
#
# Sample line from the 'security' command output, if the account name is "foobar":
#     "acct"<blob>="foobar"
#
# Yes, this is an ugly approach - but probably not worth the effort to make it elegant.
account=$( security find-generic-password -s "${keychainItem}" | grep '"acct"' | cut -d'"' -f4 )

[[ -z "${account}" ]] && { >&2 echo "Did not actually get a value back for the account name! Bailing out." ; exit 2 ; }


# Repeat the same thing, but this time to get the server name from what's saved as
# the "Comments" of the keychain item. Again, this way of doing it is ham-handed but
# by keeping the output parsing down to one "grep" and one "cut" it's easy to follow.
server=$( security find-generic-password -s "${keychainItem}" | grep '"icmt"' | cut -d'"' -f4 )

[[ -z "${server}" ]] && { >&2 echo "Did not actually get a value back for the server name! Bailing out." ; exit 2 ; }


# Whew. All that work so that we can now echo it out in the format of a .netrc file.
# https://ec.haxx.se/usingcurl-netrc.html
cat <<ENDOFNETRC

machine		${server}
login		${account}
password	${password}

ENDOFNETRC


# fin
