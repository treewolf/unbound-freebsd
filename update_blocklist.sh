#!/bin/sh
# 
# Updates unbound's blocklists and reloads services
#
# All lists given are expected to be fetched, parsed, and loaded successfully.
# If one list fails, script will print error and exit.
#
# To run:
# sh update_blocklist.sh
#

# Expects directory to be present
CONFIG_DIR="/var/unbound/conf.d/block"

# Temp directory inside /var/tmp
TEMP_SUBDIR="/var/tmp/$0"

# URLs for the block lists
LIST_ADS="https://blocklistproject.github.io/Lists/alt-version/ads-nl.txt"
LIST_SCAM="https://blocklistproject.github.io/Lists/alt-version/scam-nl.txt"
LIST_REDIRECT="https://blocklistproject.github.io/Lists/alt-version/redirect-nl.txt"
LIST_RANSOMWARE="https://blocklistproject.github.io/Lists/alt-version/ransomware-nl.txt"
LIST_PHISHING="https://blocklistproject.github.io/Lists/alt-version/phishing-nl.txt"
LIST_MALWARE="https://blocklistproject.github.io/Lists/alt-version/malware-nl.txt"
LIST_FRAUD="https://blocklistproject.github.io/Lists/alt-version/fraud-nl.txt"

# Setup tmp dir in /var/tmp
setup(){
    mkdir -p "$TEMP_SUBDIR" || ( echo Could not create directory "'$TEMP_SUBDIR'" && exit 1 )
    echo Setup complete.
}

# Gets list from the awesome github repo
# Expects 1 arg: LIST_* var
getlist(){
    cd "$TEMP_SUBDIR" || ( echo Could not change directory to "'$TEMP_SUBDIR'" && exit 1 )
    
    fetch -q "$1" || echo URL "'$1'" failed to get file && return
    echo "'$1'" fetched successfully.
}

# Parses a file
# Expects 1 argument: LIST_* variable
parselist(){
    cd "$TEMP_SUBDIR" || ( echo Could not change directory to "'$TEMP_SUBDIR'" && exit 1 )

    filename="$(echo "$1" | awk -F/ '{print $NF}' )"

    # Remove lines after '#'
    sed -i '' 's/[\s]*#.*//g' "$filename"

    # Remove empty lines
    awk 'NF > 0' "$filename"> "$filename".tmp

    # Syntax for unbound
    sed -i '' -e 's/\(.*\)/local-zone: "\1" refuse /' "$filename".tmp

    # If file is not empty, then continue
    [ -s "$filename".tmp ] || ( echo File "$filename".tmp returned empty && exit 1 )

    echo File "'$filename'" parsed successfully.
}

# Copies list to the blocklist directory
# Expects 1 arg: LIST_*
copylist(){
    filename="$(echo "$1" | awk -F/ '{print $NF}' )"
    cp "$TEMP_SUBDIR/$filename.tmp" "$CONFIG_DIR/$filename.tmp" || ( echo Failed to copy "'$TEMP_SUBDIR/$filename.tmp'" to "'$CONFIG_DIR/$filename.tmp'" && exit 1 )
}

# Commits changes to unbound config
# Expects 1 arg: LIST_*
commitlist(){
    cd "$CONFIG_DIR" || ( echo Could not change directory to "'$CONFIG_DIR'" && exit 1 )

    filename="$(echo "$1" | awk -F/ '{print $NF}' )"
    mv "$filename.tmp" "$filename"
}

# Removes lists in /var/tmp
cleantmp(){
    cd /var/tmp || ( echo Could not change directory to /var/tmp && exit 1 )

    rm "$TEMP_SUBDIR"/*
    rmdir "$TEMP_SUBDIR"
    echo Clean up process finished. Check for errors.
}

# Check unbound config for errors
servicecheck(){
    unbound-checkconf
    status=$?
    [ $status -eq 0 ] || ( echo Failed config check && return 1 )
}

# Revert changes if unbound config fails
# Expects 1 arg: LIST_*
revert(){
    filename="$(echo "$1" | awk -F/ '{print $NF}' )"
    cd "$CONFIG_DIR" || ( echo Could not change directory to "'$CONFIG_DIR'" && exit 1 )
    rm -v "$CONFIG_DIR/$filename.tmp"
}

# Start
setup
getlist "$LIST_ADS"
getlist "$LIST_SCAM"
getlist "$LIST_REDIRECT"
getlist "$LIST_RANSOMWARE"
getlist "$LIST_PHISHING"
getlist "$LIST_MALWARE"
getlist "$LIST_FRAUD"

parselist "$LIST_ADS"
parselist "$LIST_SCAM"
parselist "$LIST_REDIRECT"
parselist "$LIST_RANSOMWARE"
parselist "$LIST_PHISHING"
parselist "$LIST_MALWARE"
parselist "$LIST_FRAUD"

copylist "$LIST_ADS"
copylist "$LIST_SCAM"
copylist "$LIST_REDIRECT"
copylist "$LIST_RANSOMWARE"
copylist "$LIST_PHISHING"
copylist "$LIST_MALWARE"
copylist "$LIST_FRAUD"

servicecheck
status=$?

if [ $status -eq 0 ]; then
    commitlist "$LIST_ADS"
    commitlist "$LIST_SCAM"
    commitlist "$LIST_REDIRECT"
    commitlist "$LIST_RANSOMWARE"
    commitlist "$LIST_PHISHING"
    commitlist "$LIST_MALWARE"
    commitlist "$LIST_FRAUD"
    unbound-control reload && echo Unbound service restarted
    cleantmp
    unbound-control status
else
    echo Will revert changes. Temp files will be kept for inspection.
    revert "$LIST_ADS"
    revert "$LIST_SCAM"
    revert "$LIST_REDIRECT"
    revert "$LIST_RANSOMWARE"
    revert "$LIST_PHISHING"
    revert "$LIST_MALWARE"
    revert "$LIST_FRAUD"
    echo Revert complete.
fi
