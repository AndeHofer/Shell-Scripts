#!/bin/bash

# -----------------------------------------------------------------------------
# FUNCTION: process_single_audiobook
# PURPOSE:  Flattens a single book folder by moving files out of subfolders.
# -----------------------------------------------------------------------------
process_single_audiobook() {
    local PARENT_DIR="$1"
    local AUDIO_EXT='.*\.(mp3|m4a|m4b|flac|wav|ogg|opus|wma)$'

    echo "Processing audiobook: $(basename "$PARENT_DIR")"

    # Enter the book folder
    pushd "$PARENT_DIR" > /dev/null || return

    # Loop through subdirectories (e.g., "CD 1")
    while read -r SUBDIR; do
        local SUBDIR_NAME="${SUBDIR#./}"

        if [[ -z "$SUBDIR_NAME" || "$SUBDIR_NAME" == "/" || "$SUBDIR_NAME" == "." ]]; then
            continue
        fi

        # Replace spaces in the folder name with underscores for the prefix
        local CLEAN_SUBDIR_NAME="${SUBDIR_NAME// /_}"

        # Find and rename audio files
        while read -r FILE_PATH; do
            local FILENAME
            FILENAME=$(basename "$FILE_PATH")
            local NEW_NAME

            if [[ "$FILENAME" =~ ^([^_-]+)([_-])(.*)$ ]]; then
                local SEP="${BASH_REMATCH[2]}"
                NEW_NAME="${CLEAN_SUBDIR_NAME}${SEP}${FILENAME}"
            else
                NEW_NAME="${CLEAN_SUBDIR_NAME}_${FILENAME}"
            fi

            local TARGET_FILE="./$NEW_NAME"

            if [ -e "$TARGET_FILE" ]; then
                mv "$FILE_PATH" "./CONFLICT_${CLEAN_SUBDIR_NAME}_${FILENAME}"
            else
                mv "$FILE_PATH" "$TARGET_FILE"
            fi
        done < <(find "$SUBDIR_NAME" -maxdepth 1 -type f -regextype posix-extended -iregex "$AUDIO_EXT")

        # Delete empty subfolder
        if [ -d "$SUBDIR_NAME" ] && [ ! -L "$SUBDIR_NAME" ]; then
            rm -rf -- "$SUBDIR_NAME"
        fi

    done < <(find . -mindepth 1 -maxdepth 1 -type d)

    popd > /dev/null || return
}

# -----------------------------------------------------------------------------
# FUNCTION: main
# PURPOSE:  Handles backup creation and library iteration.
# -----------------------------------------------------------------------------
main() {
    local LIBRARY_PATH_RAW="$1"

    if [ -z "$LIBRARY_PATH_RAW" ]; then
        echo "Usage: $0 /path/to/audiobooks_library"
        return 1
    fi

    local LIBRARY_DIR
    LIBRARY_DIR=$(realpath "$LIBRARY_PATH_RAW")

    if [ ! -d "$LIBRARY_DIR" ]; then
        echo "Error: '$LIBRARY_DIR' is not a directory."
        return 1
    fi

    # --- BACKUP STEP ---
    # Create a Backup folder one level above the library folder
    local BACKUP_ROOT
    BACKUP_ROOT="$(dirname "$LIBRARY_DIR")/Backup"

    echo "Creating backup at: $BACKUP_ROOT"
    mkdir -p "$BACKUP_ROOT"

    # Copy the entire library into the Backup folder before processing
    # -r: recursive, -p: preserve attributes
    cp -rp "$LIBRARY_DIR" "$BACKUP_ROOT/"
    echo "Backup complete."

    # --- PROCESSING STEP ---
    while read -r BOOK_PATH; do
        # Check depth to avoid breaking complex structures
        local NESTED_CHECK
        NESTED_CHECK=$(find "$BOOK_PATH" -mindepth 2 -type d)

        if [ -n "$NESTED_CHECK" ]; then
            echo "Skipping $(basename "$BOOK_PATH"): Structure too deep."
            continue
        fi

        process_single_audiobook "$BOOK_PATH"

    done < <(find "$LIBRARY_DIR" -mindepth 1 -maxdepth 1 -type d)

    echo "---------------------------------------"
    echo "Batch processing complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$1"
fi