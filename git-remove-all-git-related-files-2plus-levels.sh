#!/usr/bin/env bash
set -u
set -e
set -o pipefail
set -o posix

[[ ${debug:-} == "true" ]] && set -x

script_dir=$(dirname $(readlink -f $0))

cd $1
echo "Files recursively named .gitignore .gitattributes .gitmodules"

IFS=$'\n\r'
for file in $( git ls-files ./**/.gitignore  ) ; do
  git rm -rf "$file"
done
for file in $( git ls-files ./**/.gitattributes  ) ; do
  git rm -rf "$file"
done
for file in $( git ls-files ./**/.gitmodules  ) ; do
  git rm -rf "$file"
done
