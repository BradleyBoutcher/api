#!/bin/zsh

# The following script can be used to convert dot-delimited
# item names from a given file into paths and / or yml files.
# The final item in the dot-delimited item will be excluded, as it
# will be the entry name in the resulting file.

# Run from top-level dir
cd "$(dirname "$0")"

# Spec we're using as a base
readonly SPEC="openapi-3.yml"
# File to parse
readonly ENTRIES="entries.txt"
# File to store mappings of entries to their filepaths 
readonly MAPPINGS="mappings.txt"
# Top-level directory containing openapi files
readonly TOP_LEVEL_DIR="./test"
# File containing uncategorized entries
readonly SHARED_FILE="shared.yml"

# # Cleanup
rm -rf $TOP_LEVEL_DIR 2> /dev/null
rm -rf $MAPPINGS 2> /dev/null
rm -rf $ENTRIES 2> /dev/null

# Generate our list of entries
yq eval '(.components.schemas | keys | .[] )' "$SPEC" > "$ENTRIES"    

touch $MAPPINGS

# Begin creating our fragmented spec
while read line; do 
    # Replace all periods in the line with spaces
    # convert to lowercase
    # Take the newly separated words and put them in an array
    words=( `echo $line | tr . " "` ) 
    echo "Words: ${words[@]}"
    
    # Retrieve entry
    entry=$(line="$line" yq eval '.components.schemas.[env(line)]' openapi-3.yml)
    # Retrieve the name of our entry
    entryname="${words[-1]}"

    # Remove the nth item (we don't need it anymore)
    words=${words[@]:0:${#words[@]}-1}
    
    # Get the length of our word array
    length=${#words[@]}

    filepath=""
    # If there's no words left, skip it
    if [[ $length -lt 1 ]]; then
        echo "Single-item entry, adding to shared file..."
        filepath="$SHARED_FILE"
    elif [[ $length -eq 1 ]]; then 
    # If there's only one word left, make a file
        filepath="${words[0]}"
    else 
    # Convert all words to a single string
        filepath="${words[@]// //}.yml"
    fi
    
    # Record the entry and the associated filepath
    echo "$entryname $line $filepath" >> $MAPPINGS

    # Lowercase expansion for ZSH shells
    filepath="$TOP_LEVEL_DIR/${filepath:l}"

    # Create our filepath, if needed
    if [ ! -f "$filepath" ]; then
        mkdir -p "$(dirname "$filepath")" && touch "$filepath"
        echo "components:" >> "$filepath"
        echo "  schemas:" >> "$filepath"
        echo "$filepath created!"
    else 
        echo "File exists, skipping..."
    fi

    # Add our new shortened entry name
    echo "$entryname:" | awk '{ print "    " $0 }' >> $filepath
    # Add the entire entry 
    echo "$entry" | awk '{ print "      " $0 }' >> $filepath
    # Add a space between entries
    echo >> $filepath

    echo
done < $ENTRIES

declare -a files 
# files=($(find "$TOP_LEVEL_DIR" -type f))
files=("./test/openapi.yml")

# Recursively "fix" refs
while read line; do
    words=(`echo ${line}`);
    
    entryname=${words[1]}
    oldref=${words[2]}   
    filepath="$TOP_LEVEL_DIR/${words[3]:l}"
    # Get absolute path for source file
    filepath=$(realpath $filepath)

    echo "
    ============
    Now replacing incorrect references for $oldref
    Location for entry: $filepath
    ============
    "

    # We first need to create a period-escaped string
    # representation of the entry we want to replace
    # First, escape periods
    target="$(echo $oldref | sed 's/[.]/\\./g')"
    # Second, escape left brackets (some entries end with [])
    target="$(echo $target | sed 's/\[/\\[/g')"
    # Finally, escape right brackets
    target="$(echo $target | sed 's/\]/\\]/g')"

    # For every new file, check if there's a reference to the entry
    # If we find it, replace it with its new path.
    for file in ${files[@]}; do
        # Get absolute path for target file
        dir=$(realpath $file)
        echo "Replacing in $dir..."
        # Location of file relative to current file
        relative_path=$(realpath --relative-to="$dir" "$filepath")

        # Fix off-by-one directory 
        if [[ "$relative_path" == "." ]]; then
            relative_path=""
        else
            relative_path=$(echo "$relative_path" | sed "s~^../~~g")
        fi

        echo "Entry location relative to current file: $relative_path"
        # New location
        new_ref="'$relative_path#/components/schemas/$entryname'"
        # Replace replace replace
        sed -i '' "s~'.*$target'~$new_ref~g" $file
    done

done < $MAPPINGS
