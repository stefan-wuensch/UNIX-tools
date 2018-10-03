#!/usr/bin/env bash
# shellcheck disable=SC1117

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

####################################################################################################



# Set safe path
PATH=/usr/bin:/bin:/usr/local/bin
export PATH



####################################################################################################
usage() {

	echo "Usage: ${0} url-to-download"
	echo "Example: ${0} http://mydomain.com/path/to/foo.pdf"
	exit 1
}



####################################################################################################
# Return last (far right) slash-delimited element of URL string
# Example: 
#    Input "http://mydomain.com/path/to/foo.pdf"
#    Output "foo.pdf"

filename_from_url() {
	echo $( echo "${1}" | awk -F/ '{print $NF}' )
}



####################################################################################################
# Usage: mtime_for_platform "name_of_file"
# Returns: last modified time stamp of file, as YYYY-MM-DD_HHMM like 2017-11-02_1230
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
handle_collision() {

	handle_this_url="${1}"
	handle_this_filename="$( filename_from_url ${handle_this_url} )"

	# Escape the variable because we don't have the value set yet.
	trap "rm -f \${TMPFILE}; exit 0" EXIT HUP INT QUIT TERM

	basename=$( basename ${0} )
	TMPFILE=$( mktemp /tmp/${basename}.XXXXXXXXX ) || { echo "Error - coult not make temp file" ; exit 1 ; }

	get_it "${handle_this_url}" "${TMPFILE}"
	[[ ! -s "${TMPFILE}" ]] && echo "Got zero bytes for file - error" && exit 1

	sum_new=$( shasum -a 256 "${TMPFILE}" | awk '{print $1}' )
	sum_existing=$( shasum -a 256 "${handle_this_filename}" | awk '{print $1}' )

	if [[ "${sum_new}" != "${sum_existing}" ]] ; then
		echo "Existing file differs from new file even though names are the same. Renaming the old."
		echo "existing file mtime $( mtime_for_platform ${handle_this_filename} )"
		echo "new file mtime $( mtime_for_platform ${TMPFILE} )"

		# If there's a dot in the file name, we'll assume it's an extension.
		if [[ "${handle_this_filename}" =~ \. ]] ; then
			name_part="${handle_this_filename%.*}"
			extension="${handle_this_filename##*.}"
			mv "${handle_this_filename}" "${name_part}.$( mtime_for_platform ${handle_this_filename} ).${extension}"
			mv "${TMPFILE}" "${name_part}.$( mtime_for_platform ${TMPFILE} ).${extension}"
		else
			mv "${handle_this_filename}" "${handle_this_filename}.$( mtime_for_platform ${handle_this_filename} )"
			mv "${TMPFILE}" "./${handle_this_filename}.$( mtime_for_platform ${TMPFILE} )"
		fi
	fi

	# Cleanup in aisle 3
	rm -f ${TMPFILE}
	trap "" EXIT HUP INT QUIT TERM

}


####################################################################################################


# Main program start

# Handle wrong number of args and help
[[ ${#} -ne 1 ]] && usage
[[ "${1}" == "-h" ]] && usage
[[ "${1}" == "--help" ]] && usage


url="${1}"
filename=$( filename_from_url ${url} )

if [[ -f "${filename}" ]] ; then
	echo "Found \"${filename}\" already there - processing name collision..."
	handle_collision "${url}"
else
	get_it "${url}"
fi

ls -ld "${filename}"*
