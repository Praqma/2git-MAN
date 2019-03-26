#!/usr/bin/env bash

ccm_project_name=$1
repo_convert_rev_tag=$2
repo_convert_instance=$3

test "${ccm_project_name}x" == "x"      && ( echo "'ccm_project_name' not set - exit"       && exit 1 )
test "${repo_convert_rev_tag}x" == "x"  && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )
test "${repo_convert_instance}x" == "x"  && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )

create_time=$(ccm properties -f "%{create_time[dateformat='yyyy-MM-dd HH:MM:SS']}" "${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}")

if [ "${create_time}x" == "x" ] ; then
    exit 1
else
    echo ${create_time}
fi