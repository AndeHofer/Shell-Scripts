#!/bin/bash

flatten_directory() {
    local TARGET_PATH_RAW="$1"

    if [ -z "$TARGET_PATH_RAW" ]; then
        echo "Usage: $0 /path/to/parent_folder"
        return 1
    fi

    local PARENT_DIR
    PARENT_DIR=$(realpath "$TARGET_PATH_RAW")

    if [ ! -d "$PARENT_DIR" ]; then
        echo "Error: '$PARENT_DIR' is not a directory."
        return 1
    fi

    # Depth Validation
    local NESTED_DIRS
    NESTED_DIRS=$(find "$PARENT_DIR" -mindepth 2 -type d)
    if [ -n "$NESTED_DIRS" ]; then
        echo "Error: Directory structure too deep. Found: $NESTED_DIRS"
        return 1
    fi

    cd "$PARENT_DIR" || return 1

    local AUDIO_EXT='.*\.(mp3|m4a|m4b|flac|wav|ogg|opus|wma)$'

    # Process subdirectories
    while read -r SUBDIR; do
        local SUBDIR_NAME="${SUBDIR#./}"

        if [[ -z "$SUBDIR_NAME" || "$SUBDIR_NAME" == "/" || "$SUBDIR_NAME" == "." ]]; then
            continue
        fi

        # NEW: Remove all spaces from the subdirectory name for the prefix
        local CLEAN_SUBDIR_NAME="${SUBDIR_NAME// /}"

        # Process Audio Files inside the subdirectory
        while read -r FILE_PATH; do
            local FILENAME
            FILENAME=$(basename "$FILE_PATH")
            local NEW_NAME

            # Detect first separator (_ or -) to maintain style
            if [[ "$FILENAME" =~ ^([^_-]+)([_-])(.*)$ ]]; then
                local SEP="${BASH_REMATCH[2]}"
                # Prefix is the cleaned folder name + original separator + filename
                NEW_NAME="${CLEAN_SUBDIR_NAME}${SEP}${FILENAME}"
            else
                # Fallback: Default to underscore
                NEW_NAME="${CLEAN_SUBDIR_NAME}_${FILENAME}"
            fi

            local TARGET_FILE="./$NEW_NAME"

            if [ -e "$TARGET_FILE" ]; then
                echo "Conflict: $NEW_NAME already exists. Using CONFLICT prefix."
                mv "$FILE_PATH" "./CONFLICT_${CLEAN_SUBDIR_NAME}_${FILENAME}"
            else
                mv "$FILE_PATH" "$TARGET_FILE"
            fi
        done < <(find "$SUBDIR_NAME" -maxdepth 1 -type f -regextype posix-extended -iregex "$AUDIO_EXT")

        # Cleanup: Remove the subfolder (using original name with spaces!)
        if [ -d "$SUBDIR_NAME" ] && [ ! -L "$SUBDIR_NAME" ]; then
            echo "Removing subfolder: $SUBDIR_NAME"
            rm -rf -- "$SUBDIR_NAME"
        fi

    done < <(find . -mindepth 1 -maxdepth 1 -type d)

    echo "Process complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    flatten_directory "$1"
fi