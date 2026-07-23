#!/bin/bash

# Define directory and file names
DIR_NAME="my_directory"
FILE1="file1.txt"
FILE2="file2.txt"

# Define permissions
DIR_PERM=755  # Read, write, execute for owner; read-execute for others
FILE_PERM=644 # Read-write for owner; read-only for others

# Create directory if it doesn't exist
if [ ! -d "$DIR_NAME" ]; then
    mkdir "$DIR_NAME"
    echo "Directory '$DIR_NAME' created."
else
    echo "Directory '$DIR_NAME' already exists."
fi

# Set directory permissions
chmod $DIR_PERM "$DIR_NAME"
echo "Permissions set for directory: $DIR_NAME ($DIR_PERM)"

# Create files inside the directory
touch "$DIR_NAME/$FILE1"
touch "$DIR_NAME/$FILE2"

# Set file permissions
chmod $FILE_PERM "$DIR_NAME/$FILE1"
chmod $FILE_PERM "$DIR_NAME/$FILE2"

echo "Files '$FILE1' and '$FILE2' created in '$DIR_NAME'."
echo "Permissions set for files: $FILE1, $FILE2 ($FILE_PERM)"
