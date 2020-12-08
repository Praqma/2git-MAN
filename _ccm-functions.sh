#!/usr/bin/env bash

function find_n_set_baseline_obj_attrs_from_project(){
    local ccm_project_4part=$1
    local verbose="true"
    [[ ${2:-} == "verbose_false" ]] && local verbose="false"

    ccm_proj_obj_string=`printf "${ccm_project_4part}" | sed -e 's/xxx/ /g'`

    regex_4part='^(.+)~(.+):(.+):(.+)$'
    [[ ${ccm_project_4part} =~ ${regex_4part} ]] || exit 1
    proj_name=${BASH_REMATCH[1]}
    proj_version=${BASH_REMATCH[2]}
    proj_instance=${BASH_REMATCH[4]}
    project_release=$(ccm properties -f "%release" "${ccm_proj_obj_string}") || return $?
    if [[ "$project_release" == "<void>" ]]; then
      project_release="void"
      release_query=""
    else
      release_query=" and release='${project_release}'"
    fi

    # Find the baseline object of the project with the same release as the project itself
    ccm_baseline_obj_and_status_release_this=$(ccm query "has_project_in_baseline('${ccm_proj_obj_string}') ${release_query}" -sby create_time -u -f "%objectname@@@%status@@@%release" | head -1 )
    regex_baseline_attr='^(.+)@@@(.+)@@@(.+)$'
    if [[ "${ccm_baseline_obj_and_status_release_this:-}" == "" ]]; then
        # No baseline found with primary release tag .. See if other baseline objects are connected ( eg. list any Baseline Object and accept the first )
        ccm_baseline_obj_and_status_release_this=$(ccm query "has_project_in_baseline('${ccm_proj_obj_string}')" -sby create_time  -u -f "%objectname@@@%status@@@%release" | head -1 )
        if [[ "${ccm_baseline_obj_and_status_release_this:-}" == "" ]]; then
            if [[ "${verbose:-}" == "true" ]]; then
              echo "NOTE: No related Baseline Object not found at all: ${ccm_project_4part}" >&2
            fi
        else
            [[ ${ccm_baseline_obj_and_status_release_this} =~ ${regex_baseline_attr} ]] || exit 1
            ccm_baseline_obj=${BASH_REMATCH[1]}
            ccm_baseline_status=${BASH_REMATCH[2]}
            ccm_baseline_release=${BASH_REMATCH[3]}
            if [[ ${verbose:-} == "true" ]]; then
              echo "NOTE: release diff found.. ${ccm_project_4part} / ${project_release} <=> ${ccm_baseline_release} / ${ccm_baseline_obj} - accepted" >&2
            fi
        fi
    else
        [[ ${ccm_baseline_obj_and_status_release_this} =~ ${regex_baseline_attr} ]] || exit 1
        ccm_baseline_obj=${BASH_REMATCH[1]}
        ccm_baseline_status=${BASH_REMATCH[2]}
        ccm_baseline_release=${BASH_REMATCH[3]}
    fi
}