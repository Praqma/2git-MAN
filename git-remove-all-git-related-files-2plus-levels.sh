#!/usr/bin/env bash
set -u
set -e
set -o pipefail
set -o posix

[[ ${debug:-} == "true" ]] && set -x
pwd
cd $1
pwd
echo "Files recursively named .gitignore .gitattributes .gitmodules"

find . -mindepth 2 -type f -name '.gitignore' -o -name '.gitmodules' -o -name '.gitattributes' > remove_files.tmp || touch remove_files.tmp
cat remove_files.tmp

IFS=$'\n\r'
for file in $(cat remove_files.tmp) ; do
  echo "remove file: $file"
  [[ ${dryrun:-} == true ]] || rm -f "$file"
done
exit

IFS=$'\n\r'
for file in $( git ls-files ./**/.gitignore  ) ; do
  rm -rf "$file"
done
for file in $( git ls-files ./**/.gitattributes  ) ; do
  rm -rf "$file"
done
for file in $( git ls-files ./**/.gitmodules  ) ; do
  rm -rf "$file"
done