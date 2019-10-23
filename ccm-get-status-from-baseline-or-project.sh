#!/usr/bin/env bash
set -u
set -e

# Load functions
source $(dirname $0)/_ccm-functions.sh || source ./_ccm-functions.sh

ccm_project_name=$1
repo_convert_rev_tag=$2
repo_convert_instance=$3

[[ "${ccm_project_name:-}" == "" ]]       && ( echo "'ccm_project_name' not set - exit"       && exit 1 )
[[ "${repo_convert_rev_tag:-}" == "" ]]   && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )
[[ "${repo_convert_instance:-}" == "x" ]] && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )

exit_code="0"
find_n_set_baseline_obj_attrs_from_project "${ccm_project_name}~${repo_convert_rev_tag}:project:${repo_convert_instance}" "verbose_false" || exit_code=$?
if [[ "${exit_code}" != "0" ]] ; then
    echo "ERROR: Project not found: ${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}"
    exit ${exit_code}
fi

if [[ "${ccm_baseline_status:-}" == "" ]]; then
    # We could not set status from baseline object - take it from the project
    ccm_baseline_status=`ccm attr -show status "${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}" |  sed -e 's/ //g' |  cut -c1-3`
else
    ccm_baseline_status=`echo ${ccm_baseline_status} |  cut -c1-3`
fi
if [[ "${ccm_baseline_status:-}" == "" ]] ; then
    echo "Something went wrong as no status is set"
    exit 1
else
    echo ${ccm_baseline_status}
fi