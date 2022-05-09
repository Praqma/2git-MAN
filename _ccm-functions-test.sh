#!/usr/bin/env bash

# Load functions
source ./_ccm-functions.sh || source ${BASH_SOURCE%/*}/_ccm-functions.sh

[[ "${debug:-}" == "true" ]] && set -x


set -euo pipefail

ccm_project_name="Create NG_shared_MPC55xx_dev_ser"
expected_result="Create-NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_ccm_project_name_string2git_repo_name_string" "${ccm_project_name} -> $expected_result"
byref_translate_from_ccm_project_name_string2git_repo_name_string ccm_project_name result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${ccm_project_name} != $result\n" ;}

ccm_project_name="Create-NG_shared_MPC55xx_dev_ser"
expected_result="Create?NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_git_repo_name_string2ccm_project_name_query_string" "${ccm_project_name} -> $expected_result"
byref_translate_from_git_repo_name_string2ccm_project_name_query_string ccm_project_name result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${ccm_project_name} != $result\n" ;}

ccm_query_name_instance_string="Create?NG_shared_MPC55xx_dev_ser"
ccm_query_instance="1"
expected_result="Create NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_ccm_project_name_query_string2ccm_project_name" "${ccm_query_name_instance_string} -> $expected_result"
byref_translate_from_ccm_project_name_query_string2ccm_project_name ccm_query_name_instance_string ccm_query_instance result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${ccm_project_name} != $result\n" ;}

git_repo_name="Create-NG_shared_MPC55xx_dev_ser"
ccm_query_instance="1"
expected_result="Create NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_git_repo_name_string2ccm_project_name_string" "${ccm_project_name} -> $expected_result"
byref_translate_from_git_repo_name_string2ccm_project_name_string git_repo_name ccm_query_instance result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${ccm_project_name} != $result\n" ;}


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
