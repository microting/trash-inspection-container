import os
import xml.etree.ElementTree as ET
import sys

# Dictionary to store the package names and their versions
packages = {}

# Dictionary to store the .csproj files that contain each package version
proj_files = {}

# Loop through all .csproj files in the current directory and its subdirectories
for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".csproj"):
            # Parse the .csproj file with ElementTree
            tree = ET.parse(os.path.join(root, file))
            root_elem = tree.getroot()

            # Find all PackageReference elements in the .csproj file and add them to the packages dictionary
            for package in root_elem.findall(".//PackageReference"):
                package_name = package.attrib.get("Include")
                package_version = package.attrib.get("Version")
                if package_name and package_version:
                    if package_name not in packages:
                        packages[package_name] = []
                    packages[package_name].append(package_version)

                    # Store the .csproj file that contains each package version
                    if package_version not in proj_files:
                        proj_files[package_version] = []
                    proj_files[package_version].append(os.path.join(root, file))

# Loop through the packages and print the ones that have more than one version
for package_name, versions in packages.items():
    unique_versions = set(versions)
    if len(unique_versions) > 1:
        print(f"{package_name}:")
        for version in sorted(unique_versions):
            print(f"\t{version} (found in {len(proj_files[version])} .csproj files):")
            for proj_file in proj_files[version]:
                print(f"\t\t{proj_file}")

# If there are no packages with more than one version, write a message and exit with a status code of 0
if not any(len(set(versions)) > 1 for versions in packages.values()):
    print("No packages with multiple versions found.")
    sys.exit(0)

# Otherwise, exit with a non-zero status code
sys.exit(1)
