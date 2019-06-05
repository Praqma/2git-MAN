#!/bin/bash
[[ $debug == "TRUE" ]] && ( set -x && debug="true" )
set -e

BASELINE_PROJECT=$1
UNTIL_PROJECT=$2

handle_baseline2(){
    local CURRENT_PROJECT=$1
    local inherited_string_local=$2
	proj_name=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $1}'`
    proj_version=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $2}'`
    proj_instance=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $4}'`

    # All status versions
    query="has_baseline_project(name match '${proj_name}*' and version='${proj_version}' and type='project' and instance='${proj_instance}') and ( status='integrate' or status='test' or status='sqa' or status='released' )"
    local SUCCESSOR_PROJECTS=`ccm query "${query}" -u -f "%objectname" | sed -e 's/ /xxx/g'`
    [[ $debug == "true" ]] && printf "_________________________\n$SUCCESSOR_PROJECTS\n"
    for SUCCESSOR_PROJECT in ${SUCCESSOR_PROJECTS} ; do
        local inherited_string="${inherited_string_local} -> ${CURRENT_PROJECT}"
        [[ $debug == "true" ]] && printf "${inherited_string}\n"
        grep "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT" ${projects_file} && continue # Next if already for some odd reason exists - seen in firebird~BES-SW-0906-1.8:project:2
        printf "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT\n" >> ${projects_file}
        handle_baseline2 ${SUCCESSOR_PROJECT} "${inherited_string}"
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
