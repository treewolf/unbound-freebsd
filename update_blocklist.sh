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

# Name of final file
FINAL_NAME="merged.txt"

# URLs for the block lists
LIST_BL_AD="https://blocklistproject.github.io/Lists/alt-version/ads-nl.txt"
LIST_BL_SCAM="https://blocklistproject.github.io/Lists/alt-version/scam-nl.txt"
LIST_BL_REDIRECT="https://blocklistproject.github.io/Lists/alt-version/redirect-nl.txt"
LIST_BL_RANSOMWARE="https://blocklistproject.github.io/Lists/alt-version/ransomware-nl.txt"
LIST_BL_PHISHING="https://blocklistproject.github.io/Lists/alt-version/phishing-nl.txt"
LIST_BL_MALWARE="https://blocklistproject.github.io/Lists/alt-version/malware-nl.txt"
LIST_BL_FRAUD="https://blocklistproject.github.io/Lists/alt-version/fraud-nl.txt"

# Setup tmp dir in /var/tmp
setup(){
    ( mkdir -p "$TEMP_SUBDIR" && echo Setup complete. ) || ( echo Could not create directory "'$TEMP_SUBDIR'" && exit 1 )
}

# Gets list from the awesome github repo
# Expects 1 arg: LIST_* var
getlist(){
    cd "$TEMP_SUBDIR" || ( echo Could not change directory to "'$TEMP_SUBDIR'" && exit 1 )
    ( fetch -q "$1"  && echo "'$1'" fetched successfully. ) || ( echo URL "'$1'" failed to get file && exit 1)
    
}

# Parses a file
# Expects 1 argument: LIST_* variable
parselist_BL(){
    cd "$TEMP_SUBDIR" || ( echo Could not change directory to "'$TEMP_SUBDIR'" && exit 1 )

    filename="$(echo "$1" | awk -F/ '{print $NF}' )"

    # Remove lines after '#'
    sed -i '' 's/[\s]*#.*//g' "$filename"

    # Remove any 0.0.0.0
    sed -i '' 's/[\s]*0\.0\.0\.0[\s]*//g' "$filename"

    # Remove empty lines
    awk 'NF > 0' "$filename"> "$filename".tmp

    # Syntax for unbound
    sed -i '' -e 's/\(.*\)/local-zone: "\1" refuse /' "$filename".tmp

    # If file is not empty, then continue
    ( [ -s "$filename".tmp ] && echo File "'$filename'" parsed successfully. ) || ( echo File "$filename".tmp returned empty && exit 1 )   
}

# Moves final list to the blocklist directory
copylist(){
    cd "$TEMP_SUBDIR" || ( echo Could not change directory to "'$TEMP_SUBDIR'" && exit 1 )
    sort -ubif ./*.tmp -o $FINAL_NAME || (echo Failed to sort files to "$FINAL_NAME" && exit 1)
    cp -v "$TEMP_SUBDIR/$FINAL_NAME" "$CONFIG_DIR/." || ( echo Failed to copy "'$TEMP_SUBDIR/$FINAL_NAME'" to "'$CONFIG_DIR/'" && exit 1 )
}

# Removes lists in /var/tmp
cleantmp(){
    cd /var/tmp || ( echo Could not change directory to /var/tmp && exit 1 )
    ( rm "$TEMP_SUBDIR"/* && rmdir "$TEMP_SUBDIR" && echo Clean up process finished. ) || ( echo Failed to clean "'$TEMP_SUBDIR'" && exit 1)
}

# Check unbound config for errors
servicecheck(){
    unbound-checkconf
    status=$?
    [ $status -eq 0 ] || ( echo Failed config check && return 1 )
}

# Revert changes if unbound config fails
revert(){
    cd "$CONFIG_DIR" || ( echo Could not change directory to "'$CONFIG_DIR'" && exit 1 )
    rm -v "$CONFIG_DIR/$FINAL_NAME" || echo Could not remove "'$CONFIG_DIR/$FINAL_NAME'"
}

# Start
setup
getlist  "$LIST_BL_AD" &
getlist "$LIST_BL_SCAM" &
getlist "$LIST_BL_REDIRECT" & 
getlist "$LIST_BL_RANSOMWARE" &
getlist "$LIST_BL_PHISHING" &
getlist "$LIST_BL_MALWARE" &
getlist "$LIST_BL_FRAUD" &

wait

parselist_BL "$LIST_BL_AD" &
parselist_BL "$LIST_BL_SCAM" &
parselist_BL "$LIST_BL_REDIRECT" &
parselist_BL "$LIST_BL_RANSOMWARE" &
parselist_BL "$LIST_BL_PHISHING" &
parselist_BL "$LIST_BL_MALWARE" &
parselist_BL "$LIST_BL_FRAUD" &

wait

copylist
servicecheck
status=$?

if [ $status -eq 0 ]; then
    unbound-control reload && echo Unbound service restarted
    cleantmp
    unbound-control status
else
    echo Will revert changes. Temp files will be kept for inspection.
    revert
    echo Revert complete.
fi
