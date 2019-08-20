#!/bin/bash

set -e
[[ ${debug:-} == "true" ]] && set -x
set -u
BASELINE_PROJECT="$1"

use_wildcard="" # *

# Load functions
source ${BASH_SOURCE%/*}/_ccm-functions.sh || source ./_ccm-functions.sh

find_project_baseline_to_convert(){
    local CURRENT_PROJECT=$1
    local inherited_string_local=$2

    if [[ "${use_wildcard}" == "*" ]]; then
        proj_name=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $1}'`
        proj_version=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $2}'`
        proj_instance=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $4}'`
        query="has_baseline_project(name match '${proj_name}*' and version='${proj_version}' and type='project' and instance='${proj_instance}') and ( status='integrate' or status='test' or status='sqa' or status='released' )"
    else
        ccm_proj_obj_string=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g'`
        query="has_baseline_project('${ccm_proj_obj_string}') and ( status='integrate' or status='test' or status='sqa' or status='released' )"
    fi

    # All status versions
    local SUCCESSOR_PROJECTS=`ccm query "${query}" -u -f "%objectname" | sed -e 's/ /xxx/g'`
    [[ ${debug:-} == "true" ]] && printf "_________________________\n$SUCCESSOR_PROJECTS\n"
    for SUCCESSOR_PROJECT in ${SUCCESSOR_PROJECTS} ; do
        local inherited_string="${inherited_string_local} -> ${CURRENT_PROJECT}"
        [[ ${debug:-} == "true" ]] && printf "${inherited_string}\n"
        if [[ `grep "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT" ${projects_file}` ]]; then
             echo "ALREADY include in project file - continue" >&2
             continue # Next if already for some odd reason exists - seen in firebird~BES-SW-0906-1.8:project:2
        fi
        exit_code="0"
        find_n_set_baseline_obj_attrs_from_project "${SUCCESSOR_PROJECT}" "verbose_true" || exit_code=$?
        if [[ "${exit_code}" != "0" ]] ; then
            echo "ERROR: Project not found: ${SUCCESSOR_PROJECT}"
            exit ${exit_code}
        fi
        if [[ ${ccm_baseline_status:-} == "test_baseline" ]] ; then
            # Figure out if the project
            project_baseline_childs=$(ccm query "has_baseline_project('$(echo ${SUCCESSOR_PROJECT} | sed -e 's/xxx/ /g')') and ( status='integrate' or status='test' or status='sqa' or status='released' )" -u -f "%objectname" | head -1 )
            if [[ "${project_baseline_childs:-}" != "" ]]; then
                echo "Related Baseline Object is in test status: ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - but at least in use as baseline of project: ${project_baseline_childs} - accept" >&2
            else
                echo "Related Baseline Object is in test status: ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - skip" >&2
                continue
            fi
        fi
        printf "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT\n" >> ${projects_file}
        find_project_baseline_to_convert "${SUCCESSOR_PROJECT}" "${inherited_string}"
    done
}

init_project_name=`printf "${BASELINE_PROJECT}" | awk -F"~" '{print $1}'`
instance=`printf "${BASELINE_PROJECT}" | awk -F"~|:" '{print $4}' `

export projects_file="./projects.txt"
#rm -f ${projects_file}
if [ "${use_cached_project_list:-}X" == "trueX" ]; then
  if [ -e ${projects_file} ] ; then
    cat ${projects_file}
    exit 0
  fi
fi

inherited_string="${BASELINE_PROJECT}"
echo "$BASELINE_PROJECT@@@${init_project_name}~init:project:${instance}" > ${projects_file}

find_project_baseline_to_convert ${BASELINE_PROJECT} ${inherited_string}
if [[ ${debug:-} != "true" ]]; then
    cat ${projects_file}
fi
