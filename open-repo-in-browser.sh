#!/usr/bin/env bash

# open-repo-in-browser.sh
# Stefan Wuensch, 2018-05-04

# Open a Github repo URL by parsing "git remote -v"
# and "git branch" output.

# Github example: if push origin is "git@github.huit.harvard.edu:HUIT/nagios-aws-automation.git"
# and current branch is "dev"
# then URL would be "https://github.huit.harvard.edu/HUIT/nagios-aws-automation/tree/dev"

# Bitbucket example: if push origin is "git@bitbucket.org:huitcloudservices/monitoring-automation.git"
# and current branch is "master"
# then URL would be "https://bitbucket.org/huitcloudservices/monitoring-automation/commits/branch/master"

# Note: "open" command is specific to Macs.


read -r server org repo < <( git remote -v |
	grep push |
	awk -F'[@:/ ]' 'OFS=" " {print $2,$3,$4}' |
	sed -e 's/\.git$//'
)

shopt -s nocasematch

if [[ "${server}" =~ "github" ]] ; then
	URL="https://${server}/${org}/${repo}/tree/$( git branch | grep \* | cut -d ' ' -f2- )"
fi

if [[ "${server}" =~ "bitbucket" ]] ; then
	URL="https://${server}/${org}/${repo}/commits/branch/$( git branch | grep \* | cut -d ' ' -f2- )"
fi


echo "${server} URL for this repo and branch is \"${URL}\""
echo "Hit <return> to open this URL, or ^C to exit."
read foo
open "${URL}"
