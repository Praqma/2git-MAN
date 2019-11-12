#!/bin/bash
[[ ${debug:-} == true ]] && set -x
set -u
set -e

BASELINE_PROJECT="$1"

until [[ "${BASELINE_PROJECT:-}" == "" ]] ; do
	this_project4part="${BASELINE_PROJECT}"
	this_project_name=$(echo ${BASELINE_PROJECT} |  awk -F"~" '{print $1}')
	query="is_baseline_project_of('${BASELINE_PROJECT}')"
	BASELINE_PROJECT=$(ccm query "is_baseline_project_of('${BASELINE_PROJECT}')" -u -f "%objectname") || BASELINE_PROJECT=""
	baseline_name=`printf "${BASELINE_PROJECT:-}" | awk -F"~" '{print $1}'`
	if [[ "${baseline_name:-}" != "" && "${baseline_name}" != "${this_project_name}" ]]; then
	  printf "Stop traversing - name changed: '${this_project_name}' -> '$baseline_name'\n\n" 1>&2
	  printf "Get sucessors with '${this_project_name}' of baseline_project '${BASELINE_PROJECT}' (different name) as well\n\n" 1>&2
	  echo "${this_project4part}" | sed -e 's/ /xxx/g'
	  ccm query "has_baseline_project('${BASELINE_PROJECT}') and name='${this_project_name}' " -u -f "%objectname" | sed -e 's/ /xxx/g'
	  exit
	fi
	if [[ "${BASELINE_PROJECT:-}" != "" ]] ; then
		printf "${BASELINE_PROJECT} -> " 1>&2
	else
		printf "<void>\n\n" 1>&2
		break
  fi
done
printf "${this_project4part}" | sed -e 's/ /xxx/g'
