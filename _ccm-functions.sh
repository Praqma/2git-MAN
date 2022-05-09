#!/usr/bin/env bash

regex_ccm4part='^(.+)~(.+):(.+):(.+)$'



function byref_translate_from_ccm_project_name_string2git_repo_name_string() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString=$(printf "%s" "${_fromString}" | sed \
            -e 's/ /-/g' \
            )
}


function byref_translate_from_git_repo_name_string2ccm_project_name_query_string() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString=$(printf "%s" "${_fromString}" | sed \
            -e 's/-/?/g' \
            )
}


function byref_translate_from_git_string2ccm_query_quetionmark() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString=printf "%s" "${_fromString}" | sed \
            -e 's/-/?/g'
}

function byref_translate_from_git_string2ccm_query_quetionmark() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString=printf "%s" "${_fromString}" | sed \
            -e 's/-/?/g'
}


function byref_translate_from_ccm_project_name_query_string2ccm_project_name() {
  # from parameter: "pro??ject:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "project~version:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 2  - as ref - cannot be empty" && exit 1
  else
    local -n _instance=${2}
  fi
  if [[ -z ${3} ]]; then
    echo "Parameter 3  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${3}
  fi

  local _query_string="name match '$_fromString' and type='project' and instance='${_instance}'"
  local _found_project_name_instances=$(ccm query "${_query_string}" -u -f "%name:%instance" | /usr/bin/sort -u | wc -l)
  if [[ _found_project_name_instances -eq 0 ]]; then
    echo "ERROR: I found no projects with similar ? query name output  gave foo and boo "
    echo "$_query_string"
    return 1
  fi
  if [[ _found_project_name_instances -gt 1 ]]; then
    echo "ERROR: I found two or more projects with similar ? query name output -oo gave foo and boo"
    ccm query "${_query_string}" -u -f "%name:%instance"
    return 1
  fi
  _toString="$(ccm query "${_query_string}" -u -f "%name")"
}


function byref_translate_from_git_repo_name_string2ccm_project_name_string() {
  # from parameter: "pro??ject:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "project~version:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 2  - as ref - cannot be empty" && exit 1
  else
    local -n _instance=${2}
  fi
  if [[ -z ${3} ]]; then
    echo "Parameter 3  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${3}
  fi

  local _git_repo_name=$_fromString
  local _ccm_project_instance=$_instance
  local _ccm_query_name=""
  byref_translate_from_git_repo_name_string2ccm_project_name_query_string _git_repo_name _ccm_query_name
  local _query_result=""
  byref_translate_from_ccm_project_name_query_string2ccm_project_name _ccm_query_name _ccm_project_instance _query_result
  _toString=$_query_result
}

function byref_translate_from_ccm_name_string2git_repo_string() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString=$(printf "%s" "${_fromString}" | sed \
            -e 's/ /-/g' \
            )
}


function byref_translate_from_ccm_version_string2git_tag_string() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString=$(printf "%s" "${_fromString}" | sed \
            -e 's/ /-/g' \
            )
}






function byref_translate_from_ccm_string2git_string() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString=$(printf "%s" "${_fromString}" | sed \
            -e 's/ /-/g' \
            )
}


function byref_translate_from_git_string2ccm_query_wildcarded() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && return 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && return 1
  else
    local -n _toString=${2}
  fi
  _toString=$( echo "${_fromString//-/?}" )
}


function byref_translate_from_ccm4part_query2ccm_4part() {
  local -n _ccm4part_query=${1}
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && return 1
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 2 - as ref - cannot be empty" && return 1
  else
    local -n _ccm4part=${2}
  fi

  [[ "${_ccm4part_query:-}" =~ ${regex_ccm4part} ]] || {
      echo "4part does not comply"
      return 1
    }
  local name=${BASH_REMATCH[1]}
  local version=${BASH_REMATCH[2]}
  local type=${BASH_REMATCH[3]}
  local instance=${BASH_REMATCH[4]}

  _ccm4part=$(ccm query "name match '$name' and version match '$version' and type='$type' and instance='${instance}'" -u -f "%objectname")
}

function byref_translate_from_string2ccm_4part() {
  # from parameter: "pro??ject~ver??sion:<type>:<instance>"
  #  ccm query "name match 'pro??ject' and version match 'ver??sion' and type='<type>' and instance='<instance>'
  # returns and store in parameter 2:   "pro äject~ver üsion:<type>:<instance>"
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && return 1
  else
    local -n _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && return 1
  else
    local -n _2ccm4part=${2}
  fi
  _toString=$( echo "${_fromString//-/?}" )
  byref_translate_from_ccm4part_query2ccm_4part _toString _2ccm4part
}


function find_n_set_baseline_obj_attrs_from_project(){
    local ccm_project_4part=$1
    local verbose="true"
    [[ ${2:-} == "verbose_false" ]] && local verbose="false"

    [[ ${ccm_project_4part} =~ ${regex_ccm4part} ]] || exit 1
    proj_name=${BASH_REMATCH[1]}
    proj_version=${BASH_REMATCH[2]}
    proj_instance=${BASH_REMATCH[4]}

    ccm_proj_obj_string=`printf "${ccm_project_4part}" | sed -e 's/-/?/g'`

    project_release=$(ccm properties -f "%release" "${ccm_project_4part}") || return $?
    if [[ "$project_release" == "<void>" ]]; then
      project_release="void"
      release_query=""
    else
      release_query=" and release='${project_release}'"
    fi

    # Find the baseline object of the project with the same release as the project itself
    ccm_baseline_obj_and_status_release_this=$(ccm query "has_project_in_baseline('${ccm_project_4part}') ${release_query}" -sby create_time -u -f "%objectname@@@%status@@@%release" | head -1 )
    regex_baseline_attr='^(.+)@@@(.+)@@@(.+)$'
    if [[ "${ccm_baseline_obj_and_status_release_this:-}" == "" ]]; then
        # No baseline found with primary release tag .. See if other baseline objects are connected ( eg. list any Baseline Object and accept the first )
        ccm_baseline_obj_and_status_release_this=$(ccm query "has_project_in_baseline('${ccm_project_4part}')" -sby create_time  -u -f "%objectname@@@%status@@@%release" | head -1 )
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