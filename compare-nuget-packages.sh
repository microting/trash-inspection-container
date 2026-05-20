#!/bin/bash

# Check that a directory path was provided as an argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <directory_path>"
  exit 1
fi

# Extract the directory path from the command-line argument
dir_path=$1

# Find all csproj files in the directory and its subdirectories
csproj_files=$(find "$dir_path" -name '*.csproj')

# Extract package names and versions from each csproj file
declare -A packages
for csproj_file in $csproj_files; do
  while read -r package; do
    name=$(echo "$package" | grep -oP '(?<=Include=").*(?=")' | cut -d '"' -f1)
    version=$(echo "$package" | grep -oP '(?<=Version=").*(?=")' | tr -d '[:space:]')
    if [ -n "$name" ] && [ -n "$version" ]; then
      if [ "${packages[$name]}" = "" ]; then
        packages[$name]="$version:$csproj_file"
      else
        packages[$name]+=";$version:$csproj_file"
      fi
    fi
  done < <(grep -oP '<PackageReference.*Include=.*Version=.*\/>' "$csproj_file")
done

# Check for duplicates
duplicates=()
for package in "${!packages[@]}"; do
  versions=$(echo "${packages[$package]}" | cut -d';' -f1 --complement)
  declare -A unique_versions=()
  for version_file in $versions; do
    version=$(echo "$version_file" | cut -d':' -f1)
    if [ "${unique_versions[$version]}" = "" ]; then
      unique_versions[$version]="$version_file"
    else
      unique_versions[$version]+=";$version_file"
    fi
  done
  if [ "${#unique_versions[@]}" -ne 1 ]; then
    duplicates+=("$package")
  fi
done

# Output duplicates and their .csproj files
if [ "${#duplicates[@]}" -eq 0 ]; then
  echo "No packages with different versions found in the .csproj files in $dir_path"
  exit 0
else
  echo "The following packages have different versions in the .csproj files in $dir_path:"
  for package in "${duplicates[@]}"; do
    echo "$package"
    versions=$(echo "${packages[$package]}" | tr ';' '\n')
    echo "  Versions: $versions"
  done
  exit 1
fi
