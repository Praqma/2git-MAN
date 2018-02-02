#!/usr/bin/env bash

ccm_project_name=$1
repo_convert_rev_tag=$2
repo_convert_instance=$3

test "${ccm_project_name}x" == "x"      && ( echo "'ccm_project_name' not set - exit"       && exit 1 )
test "${repo_convert_rev_tag}x" == "x"  && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )
test "${repo_convert_instance}x" == "x"  && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )

ccm_baseline_obj_this=$(ccm query "has_project_in_baseline('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}') and release='$(ccm query "name='${ccm_project_name}' and version='$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g')' and type='project' and instance='${repo_convert_instance}'" -u -f "%release")'" -u -f "%objectname" | head -1 )
if [ "${ccm_baseline_obj_this}X" != "X" ]; then
    ccm_baseline_status_this=`ccm attr -show status "${ccm_baseline_obj_this}" |  cut -c1-3 `
else
    ccm_baseline_status_this=`ccm attr -show status "${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}" |  sed -e 's/ //g' |  cut -c1-3`
fi
if [ "${ccm_baseline_status_this}x" == "x" ] ; then
    exit 1
else
    echo ${ccm_baseline_status_this}
fi