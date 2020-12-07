#!/usr/bin/env bash
set -u
set -e

[[ "${debug:-}" == "true" ]] && set -x

# Load functions
source $(dirname $0)/_ccm-functions.sh || source ./_ccm-functions.sh

ccm_project_name=$1
repo_convert_rev_tag=$2
repo_convert_instance=$3

[[ "${ccm_project_name:-}" == "" ]]       && ( echo "'ccm_project_name' not set - exit"       && exit 1 )
[[ "${repo_convert_rev_tag:-}" == "" ]]   && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )
[[ "${repo_convert_instance:-}" == "x" ]] && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )

ccm_proj_obj_string="${ccm_project_name//xxx/' '}~${repo_convert_rev_tag//xxx/' '}:project:${repo_convert_instance}"


exit_code="0"
find_n_set_baseline_obj_attrs_from_project "${ccm_proj_obj_string}" "verbose_false" || exit_code=$?
if [[ "${exit_code}" != "0" ]] ; then
    echo "ERROR: Project not found: ${ccm_proj_obj_string}"
    exit ${exit_code}
fi

if [[ "${ccm_baseline_status:-}" == "" ]]; then
    # We could not set status from baseline object - take it from the project
    ccm_baseline_status=`ccm attr -show status "${ccm_proj_obj_string}" |  sed -e 's/ //g' |  cut -c1-3`
else
    ccm_baseline_status=`echo ${ccm_baseline_status} |  cut -c1-3`
fi
if [[ "${ccm_baseline_status:-}" == "" ]] ; then
    echo "Something went wrong as no status is set"
    exit 1
else
    echo ${ccm_baseline_status}
fi