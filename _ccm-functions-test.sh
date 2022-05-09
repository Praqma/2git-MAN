#!/usr/bin/env bash

# Load functions
source ./_ccm-functions.sh || source ${BASH_SOURCE%/*}/_ccm-functions.sh

[[ "$debug" == "true" ]] && set -x


set -euo pipefail

ccm_project_name="usb control_DM"
expected_result="usb-control_DM"
git_string=""
printf "%-8s: %-60s : %-75s " "test" "byref_translate_from_ccm_string2git_string" "${ccm_project_name} -> $expected_result"
byref_translate_from_ccm_project_name_string2git_repo_name_string ccm_project_name git_string
[[ "$git_string" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${ccm_project_name} != $git_string\n" ;}

exit
git_string=${expected_result}
ccm4part_query_string=""
expected_result='usb?control_DM~1.1?MD_SystemTesting_20100805:project:1'
printf "%-8s: %-60s : %-75s " "test" "byref_translate_from_git_string2ccm_query_wildcarded" "$git_string -> $expected_result"
byref_translate_from_git_string2ccm_query_wildcarded git_string ccm4part_query_string
[[ "${ccm4part_query_string}" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; } || { printf "FAILED: $git_string != ${ccm4part_query_string}\n" ;}

ccm4part_query_string="${expected_result}"
ccm4part=""
expected_result="usb-control_DM~1.1 MD_SystemTesting_20100805:project:1"
printf "%-8s: %-60s : %-75s " "test" "byref_translate_from_ccm4part_query2ccm_4part" "${ccm4part_query_string} -> ${expected_result}"
byref_translate_from_ccm4part_query2ccm_4part ccm4part_query_string ccm4part
[[ "${ccm4part}" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${ccm4part_query_string} != ${expected_result}\n" ;}
