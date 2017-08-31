#!/usr/bin/env bash

# chrome-extension-search.sh
# Stefan Wuensch 2017-08-31
#
# In order to locate Chrome Extensions from only their ID,
# this generates a Google search URL from each Extension ID
# found in your Chrome Extensions folder.
#
# Why is this useful? One day all my Chrome Extensions disappeared.
# Poof! Gone.
# The only thing I had was a backup which showed the IDs such as
# "edacconmaakjimmfgnblocblbcdcpbko". Not useful if you want to
# figure out what it is to re-install it! This script at least
# makes it quick to search Google for that ID, and it very likely
# will get you a Chrome Store result.
#
# Optional: Supply an argument of an alternate directory to search.
# (This can be very useful if you are trying to look at a Time Machine
# backup and figure out which extensions you had at a certain date
# in the past.)
#
# Output: Basic HTML you can use to track down an Extension.
#
# Example output:
# <html>
# <a href="https://www.google.com/search?q=fhgenkpocbhhddlgkjnfghpjanffonno">https://www.google.com/search?q=fhgenkpocbhhddlgkjnfghpjanffonno</a> <br>
# <a href="https://www.google.com/search?q=jlmadbnpnnolpaljadgakjilggigioaj">https://www.google.com/search?q=jlmadbnpnnolpaljadgakjilggigioaj</a> <br>
# </html>


DIR="${HOME}/Library/Application Support/Google/Chrome/Default/Extensions"

[[ $# -eq 1 ]] && DIR="${1}"

cd "${DIR}" 2>/dev/null
[[ $? -ne 0 ]] && echo "Can't 'cd' to \"${DIR}\" - bailing out." && exit 1

echo "<html>"

ls | while read thing ; do
	# Chrome Extension IDs apparently are always 32 characters
	[[ ${#thing} -ne 32 ]] && >&2 echo "Skipping \"${thing}\" because it doesn't look like an Extension ID." && continue
	url="https://www.google.com/search?q=${thing}"
	echo "<a href=\"${url}\">${url}</a> <br>"
done

echo "</html>"

# fin
