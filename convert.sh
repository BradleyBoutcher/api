#!/bin/zsh

# The following script can be used to convert dot-delimited
# item names from a given file into paths and / or yml files.
# The final item in the dot-delimited item will be excluded, as it
# will be the entry name in the resulting file.

# Run from top-level dir
cd "$(dirname "$0")"

# Spec we're using as a base
readonly spec="openapi-3.yml"
# File to parse
readonly source="entries.txt"
# Top-level directory containing openapi files
readonly top_level_dir="./openapi"
# File containing uncategorized entries
readonly shared_file="$top_level_dir/shared.yml"

yq eval '(.components.schemas | keys | .[] )' "$spec" > "$source"    

# Cleanup
rm -rf top_level_dir

# Begin parsing
while read line; do 
    # Replace all periods in the line with spaces
    # convert to lowercase
    # Take the newly separated words and put them in an array
    words=( `echo $line | tr . " "` ) 
    echo "Words: ${words[@]}"
    
    # Retrieve entry
    entry=$(line="$line" yq eval '.components.schemas.[env(line)]' openapi-3.yml)
    # Retrieve the name of our entry
    entryname="${words[-1]}:"

    # Remove the nth item (we don't need it anymore)
    words=${words[@]:0:${#words[@]}-1}
    
    # Get the length of our word array
    length=${#words[@]}

    FILEPATH=""
    # If there's no words left, skip it
    if [[ $length -lt 1 ]]; then
        echo "Single-item entry, adding to shared file..."
        FILEPATH="$shared_file"
    elif [[ $length -eq 1 ]]; then 
    # If there's only one word left, make a file
        FILEPATH="$top_level_dir/${words[0]}"
    else 
    # Convert all words to a single string
        FILEPATH="$top_level_dir/${words[@]// //}.yml"
    fi
    
    # Create our filepath, if needed
    if [ ! -f "$FILEPATH" ]; then
        mkdir -p "$(dirname "$FILEPATH")" && touch "$FILEPATH"
        echo "components:" >> "$FILEPATH"
        echo "  schemas:" >> "$FILEPATH"
        echo "$FILEPATH created!"
    else 
        echo "File exists, skipping..."
    fi

    # Add our new shortened entry name
    echo $entryname | awk '{ print "    " $0 }' >> $FILEPATH
    # Add the entire entry 
    echo $entry | awk '{ print "      " $0 }' >> $FILEPATH

    echo
done < $source