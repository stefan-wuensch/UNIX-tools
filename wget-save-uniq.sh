#!/usr/bin/env bash
# shellcheck disable=SC1117,SC2086

####################################################################################################
# wget-save-uniq.sh
# by Stefan Wuensch, 2018-10-03

# This script takes one arg, a URL to download with "wget".
# There are three different scenarios handled by this script.

# 1) If the file to be downloaded does NOT already exist in the
# current location (CWD) then it will be downloaded with no other actions.

# 2) If the file to be downloaded already exists in the CWD with the same name,
# then this script will download the new file, compare the existing and the
# new files via SHA256

# 3a) If there is no difference in the files based on the checksums,
# leave the existing file in place without any changes. In other words...
# If the file in the remote location is the same as the one we already have
# locally, then don't change anything.

# 3b) If the new file and the existing one are different based on the checksums,
# then this script will rename the existing file to include the date/time
# of last modified, and save the downloaded file similarly with its timestamp.

# Example scenario:
# - local file "foo.pdf" with timestamp Feb 6 2018 6:09 PM exists
# - the download URL is http://mydomain.com/path/to/foo.pdf
# - the remote file "foo.pdf" is different in content than the local copy
# - the time stamp of the remote (newly downloaded) file is Feb 13 2018 11:57 AM
# - results:
#      file named "foo.2018-02-06_1809.pdf" (previous file renamed)
#      file named "foo.2018-02-13_1157.pdf" (new file downloaded and renamed)

# Note: This supports two platforms, Linux and Mac, due to differences in the
# format specifiers for the "stat" command. I don't have any other platforms
# on which to test, at least right now. See function "mtime_for_platform()"
####################################################################################################


####################################################################################################
# MIT License
#
# Copyright (c) 2018 Stefan Wuensch
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
####################################################################################################




# Set safe path
PATH=/usr/bin:/bin:/usr/local/bin
export PATH


# Optional feature: in the case of a name collision, if you want the downloaded file name
# to NOT get the timestamp added to it, then make this option "N".
# If this option is "Y" then the newly-downloaded file WILL get the timestamp added to the name.
# The addition of the timestamp might not be desired in cases where you need the download
# to give you the exact file name as the remote file.
COLLISION_ADD_MTIME_NEW_FILE="N"



####################################################################################################
usage() {

	>&2 echo "Usage: ${0} url-to-download"
	>&2 echo "Example: ${0} http://mydomain.com/path/to/foo.pdf"
	exit 1
}



####################################################################################################
# Return last (far right) slash-delimited element of URL string
#
# Usage: filename_from_url "http[s]://some.domain/path/to/file.foo"
#
# Returns: far right portion of ARG1 string delimited by '/'
#
# Example:
#    Arg1 "http://mydomain.com/path/to/foo.pdf"
#    Returns "foo.pdf"

filename_from_url() {
	echo $( echo "${1}" | awk -F/ '{print $NF}' )	# return to caller
}



####################################################################################################
# Usage: mtime_for_platform "name_of_file"
#
# Returns: last modified time stamp of file, as YYYY-MM-DD_HHMM like 2017-11-02_1230
#
# Defaults to Mac OS usage of "stat" but detects Linux and changes options appropriately

mtime_for_platform() {

	filename="${1}"
	my_uname=$( uname )

	# Mac default
	stat_command="stat -f %Sm -t %F_%H%M ${filename}"

	[[ "${my_uname}" == "Linux" ]] && stat_command="stat --format=%y ${filename} | cut -d: -f1,2 | sed -e 's/ /_/' -e 's/://'"

	eval "${stat_command}"

}


####################################################################################################
# Usage: get_it "http[s]://some.domain/path/to/file" [ "output_file_name" ]
# (Arg 2 is optional)

get_it() {
	get_url="${1}"
	out_option=""

	# If there's an output file name given, combine with the wget output option
	[[ -n "${2}" ]] && out_option="-O ${2}"
	eval "wget --no-verbose ${out_option} ${get_url}"
}


####################################################################################################
# Usage: handle_collision "http[s]://some.domain/path/to/file"
# This is the function where all the special work gets done to
# manage the name collision with renaming.
#
# Returns: Partial name of file, without timestamp and without extension
#
# Example:
#   ARG1: "http://mydomain.com/path/to/file/foobar.pdf"
#   Returns: "foobar"

handle_collision() {

	handle_this_url="${1}"
	handle_this_filename="$( filename_from_url ${handle_this_url} )"

	# Escape the variable because we don't have the value set yet.
	trap "rm -f \${TMPFILE}; exit 0" EXIT HUP INT QUIT TERM

	basename=$( basename ${0} )
	TMPFILE=$( mktemp /tmp/${basename}.XXXXXXXXX ) || { >&2 echo "Error - coult not make temp file" ; exit 1 ; }

	get_it "${handle_this_url}" "${TMPFILE}"
	[[ ! -s "${TMPFILE}" ]] && >&2 echo "Got zero bytes for file - error" && exit 1

	sum_new=$( shasum -a 256 "${TMPFILE}" | awk '{print $1}' )
	sum_existing=$( shasum -a 256 "${handle_this_filename}" | awk '{print $1}' )

	if [[ "${sum_new}" != "${sum_existing}" ]] ; then
		>&2 echo "Existing file differs from newly downloaded file even though names are the same. Renaming the old."
		>&2 echo "Existing file mtime $( mtime_for_platform ${handle_this_filename} )"
		>&2 echo "New file mtime $( mtime_for_platform ${TMPFILE} )"

		# If there's a dot in the file name, we'll assume it's an extension.
		if [[ "${handle_this_filename}" =~ \. ]] ; then

			# Break apart the file name base and extension to be separate
			name_part="${handle_this_filename%.*}"
			extension="${handle_this_filename##*.}"

			# Rename the previous one
			mv "${handle_this_filename}" "${name_part}.$( mtime_for_platform ${handle_this_filename} ).${extension}"

			# Note how the next 'mv' is a rename AND move of the new file, and it's into the CWD "."
			# We operate differently depending on whether we're adding the timestamp to the new file or not.
			if [[ "${COLLISION_ADD_MTIME_NEW_FILE}" == "Y" ]] ; then
				mv "${TMPFILE}" "./${name_part}.$( mtime_for_platform ${TMPFILE} ).${extension}"
			else
				mv "${TMPFILE}" "./${handle_this_filename}"
			fi

			echo "${name_part}"	# return to caller

		else
			# If there's no extension, we just add the timestamp onto the end, easy-peasy.
			mv "${handle_this_filename}" "${handle_this_filename}.$( mtime_for_platform ${handle_this_filename} )"

			# Note how the next 'mv' is a rename AND move of the new file, and it's into the CWD "."
			# We operate differently depending on whether we're adding the timestamp to the new file or not.
			if [[ "${COLLISION_ADD_MTIME_NEW_FILE}" == "Y" ]] ; then
				mv "${TMPFILE}" "./${handle_this_filename}.$( mtime_for_platform ${TMPFILE} )"
			else
				mv "${TMPFILE}" "./${handle_this_filename}"
			fi

			echo "${handle_this_filename}"	# return to caller
		fi
	else
		>&2 echo "Existing file on disk is identical to the newly-downloaded file. Discarding the download. No change."
		echo "$( filename_from_url ${handle_this_url} )"	# return to caller
	fi

	# Cleanup in aisle 3
	rm -f ${TMPFILE}
	trap "" EXIT HUP INT QUIT TERM

}


####################################################################################################


### Main program start ###

# Handle wrong number of args and help
[[ ${#} -ne 1 ]] && usage
[[ "${1}" == "-h" ]] && usage
[[ "${1}" == "--help" ]] && usage


url="${1}"
filename=$( filename_from_url ${url} )

if [[ -f "${filename}" ]] ; then
	echo "Found \"${filename}\" already there - processing name collision..."
	name=$( handle_collision "${url}" )
else
	echo "Downloading file..."
	get_it "${url}"
	name=$( filename_from_url "${url}" )
fi

[[ -n "${name}" ]] && ls -ld "${name}"*
