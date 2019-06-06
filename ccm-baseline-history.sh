#!/bin/bash
if [[ $debug == "TRUE" ]]; then
    set -x
    export debug="true"
fi
set -e

BASELINE_PROJECT="$1"

use_wildcard="" # *

handle_baseline2(){
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
    [[ $debug == "true" ]] && printf "_________________________\n$SUCCESSOR_PROJECTS\n"
    for SUCCESSOR_PROJECT in ${SUCCESSOR_PROJECTS} ; do
        local inherited_string="${inherited_string_local} -> ${CURRENT_PROJECT}"
        [[ $debug == "true" ]] && printf "${inherited_string}\n"
        if [[ `grep "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT" ${projects_file}` ]]; then
             echo "ALREADY include in project file - continue"
             continue # Next if already for some odd reason exists - seen in firebird~BES-SW-0906-1.8:project:2
        fi
        printf "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT\n" >> ${projects_file}
        handle_baseline2 "${SUCCESSOR_PROJECT}" "${inherited_string}"
    done
}

init_project_name=`printf "${BASELINE_PROJECT}" | awk -F"~" '{print $1}'`
instance=`printf "${BASELINE_PROJECT}" | awk -F"~|:" '{print $4}' `

export projects_file="./projects.txt"
#rm -f ${projects_file}
if [ "${use_cached_project_list}X" == "trueX" ]; then
  if [ -e ${projects_file} ] ; then
    cat ${projects_file}
    exit 0
  fi
fi

inherited_string="${BASELINE_PROJECT}"
echo "$BASELINE_PROJECT@@@${init_project_name}~init:project:${instance}" > ${projects_file}

handle_baseline2 ${BASELINE_PROJECT} ${inherited_string}
if [[ $debug != "true" ]]; then
    cat ${projects_file}
fi
