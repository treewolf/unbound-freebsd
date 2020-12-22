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

# Setup tmp dir in /var/tmp
setup(){
    ( mkdir -p "$TEMP_SUBDIR" && echo Setup complete. ) || ( echo Could not create directory "'$TEMP_SUBDIR'" && exit 1 )
}

# Parses a file
# Expects 1 argument: filename
parselist(){
    cd "$TEMP_SUBDIR" || ( echo Could not change directory to "'$TEMP_SUBDIR'" && exit 1 )

    # Remove comments
    sed -i '' "s/[\s]*[#\!@].*//g" "$1"

    # Remove headers
    sed -i '' 's/127\.0\.0\.1 localhost//g' "$1"
    sed -i '' 's/::1 localhost//g' "$1"

    # Remove any 0.0.0.0
    sed -i '' 's/[\s]*0\.0\.0\.0[\s]*//g' "$1"

    # Remove any 127.0.0.1
    sed -i '' 's/[\s]*127\.0\.0\.1[\s]*//g' "$1"

    # Remove symbols
    sed -i '' 's/[|^\r]//g' "$1"

    # Remove empty lines
    awk 'NF > 0' "$1"> "$1".tmp

    # Syntax for unbound
    sed -i '' -e 's/\(.*\)/local-zone: "\1" refuse /' "$1".tmp

    # If file is not empty, then continue
    ( [ -s "$1".tmp ] && echo File "'$1'" parsed successfully. ) || ( echo File "$1".tmp returned empty && exit 1 )   
}

# Gets list from the awesome github repo
# Expects 1 arg: LIST_* var
getlist(){
    cd "$TEMP_SUBDIR" || ( echo Could not change directory to "'$TEMP_SUBDIR'" && exit 1 )
    filename=$( echo "$1" | md5 -q )
    ( fetch -q "$1" -o "$filename" && echo "'$1'" fetched successfully. && parselist "$filename") || ( echo URL "'$1'" failed to get file && exit 1 )
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
    ( rm "$TEMP_SUBDIR"/* && rmdir "$TEMP_SUBDIR" && echo Clean up process finished. ) || ( echo Failed to clean "'$TEMP_SUBDIR'" && exit 1 )
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
getlist "https://blocklistproject.github.io/Lists/alt-version/ads-nl.txt" &
getlist "https://blocklistproject.github.io/Lists/alt-version/scam-nl.txt" &
getlist "https://blocklistproject.github.io/Lists/alt-version/redirect-nl.txt" & 
getlist "https://blocklistproject.github.io/Lists/alt-version/ransomware-nl.txt" &
getlist "https://blocklistproject.github.io/Lists/alt-version/phishing-nl.txt" &
getlist "https://blocklistproject.github.io/Lists/alt-version/malware-nl.txt" &
getlist "https://blocklistproject.github.io/Lists/alt-version/fraud-nl.txt" &
getlist "https://raw.githubusercontent.com/Yhonay/antipopads/master/hosts" &
getlist "https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt" &

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
