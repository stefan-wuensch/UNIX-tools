#!/usr/bin/env bash

# open-repo-in-browser.sh
# Stefan Wuensch, 2018-05-04

# Open a Github repo URL by parsing "git remote -v"
# and "git branch" output.

# Example: if push origin is "git@github.huit.harvard.edu:HUIT/nagios-aws-automation.git"
# and current branch is "dev"
# then URL would be "https://github.huit.harvard.edu/HUIT/nagios-aws-automation/tree/dev"

# Note: "open" command is specific to Macs.


read -r server org repo < <( git remote -v |
	grep push |
	awk -F'[@:/ ]' 'OFS=" " {print $2,$3,$4}' |
	sed -e 's/\.git$//'
)

URL="https://${server}/${org}/${repo}/tree/$( git branch | grep \* | cut -d ' ' -f2- )"

echo "Github URL for this repo and branch is \"${URL}\""
echo "Hit <return> to open this URL, or ^C to exit."
read foo
open "${URL}"
