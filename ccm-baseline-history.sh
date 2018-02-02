#!/bin/bash
#set -x #
set -e

#export PATH="/c/Program Files (x86)/IBM/Rational/Synergy/7.2.1/bin:${PATH}"
#export PATH="/mnt/synergy/ccm721/bin/ccm:${PATH}"

BASELINE_PROJECT=$1
UNTIL_PROJECT=$2

if [ "${query_type}X" == "X" ] ; then
   export query_type="all_static"
fi

if [ "${BASELINE_SUBPROJECT}X" != "X" ]; then
	SUBPROJECT_NAME=`echo ${BASELINE_SUBPROJECT} | awk -F"~|:" '{print $1}'`
fi

handle_baseline2(){
    local CURRENT_PROJECT=$1
    local inherited_string_local=$2
	proj_name=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $1}'`
    proj_version=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $2}'`
    proj_instance=`printf "${CURRENT_PROJECT}" | sed -e 's/xxx/ /g' | awk -F"~|:" '{print $4}'`
if [ "${query_type}X" == "all_staticX" ] ; then
    # All status versions
    query="has_baseline_project('${proj_name}~${proj_version}:project:${proj_instance}') and ( status='integrate' or status='test' or status='sqa' or status='released' )"
fi
if [ "${query_type}X" == "released_in_baselinesX" ] ; then
    # static projects but leave out non-released that is not in use as a baseline
	query="has_baseline_project('${proj_name}~${proj_version}:project:${proj_instance}') and ( status='released' ) or \
        (is_baseline_project_of(has_baseline_project(has_baseline_project('${proj_name}~${proj_version}:project:${proj_instance}') and ( status='integrate' or status='test' or status='sqa' or status='released' ))))"
fi
    local SUCCESSOR_PROJECTS=`ccm query "${query}" -u -f "%objectname" | sed -e 's/ /xxx/g'`
    for SUCCESSOR_PROJECT in ${SUCCESSOR_PROJECTS} ; do
		local inherited_string="${inherited_string_local} -> \"${BASELINE_PROJECT}\""
		printf "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT\n" >> ${projects_file}
		handle_baseline2 ${SUCCESSOR_PROJECT} "${inherited_string}"
	done
}

#   set -x
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

inherited_string="\"${BASELINE_PROJECT}\""
echo "$BASELINE_PROJECT@@@${init_project_name}~init:project:${instance}" > ${projects_file}
handle_baseline2 ${BASELINE_PROJECT} ${inherited_string}
cat ${projects_file}
#rm -f ${projects_file}
