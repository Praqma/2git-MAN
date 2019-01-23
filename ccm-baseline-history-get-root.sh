#!/bin/bash
#set -x

BASELINE_PROJECT=$1
UNTIL_PROJECT=$2

until [ "${BASELINE_PROJECT}X" == "X" -o "$BASELINE_PROJECT" == "$UNTIL_PROJECT" ] ; do
    BASELINE_PROJECT=`printf "${BASELINE_PROJECT}" | sed -e 's/xxx/ /g' `
	query="is_baseline_project_of('${BASELINE_PROJECT}')"
	BASELINE_PROJECT=`ccm query "is_baseline_project_of('${BASELINE_PROJECT}')" -u -f "%objectname" | sed -e 's/ /xxx/g'`
	bl_print=`printf "${BASELINE_PROJECT}" | awk -F"~" '{print $2}'`
	if [ "${BASELINE_PROJECT}X" != "X" ] ; then
		printf "${BASELINE_PROJECT} -> "
	fi
done
printf "void\n"
printf "FINAL $BASELINE_PROJECT"
exit 0
