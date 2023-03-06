#!/usr/bin/env bash
[[ ${debug:-} == "true" ]] && set -x
[[ ${run_local:-} == "true" ]] && push_remote="false"
set -u
set -e
set -o pipefail

# Load functions
source $(dirname $0)/_ccm-functions.sh || source ./_ccm-functions.sh
source $(dirname $0)/_git-functions.sh || source ./_git-functions.sh

execution_root_directory=$(pwd)

# parameter $1 is the project list file generated by the baseline_history.sh script
export repo_name=${1}

export repo_init_tag=${2}
export repo_submodules=${3}
[[ ${submodule_update_mode:-} == "" ]] && export submodule_update_mode="directory" # or update-index which is old style
[[ ${push_tags_in_submodules:-} == "" ]] && export push_tags_in_submodules="false"
[[ "${execute_mode:-}" == "" ]] && export execute_mode="normal"

export gitrepo_project_original=${4}
export project_instance=${5}
export gitignore_path_n_files=${6} # <relative_path>:<gitignore_file>@<relative_path>:<gitignore_file>..
export gitattributes_path_n_files=${7:-} # <relative_path>:<gitattributes_file>@<relative_path>:<gitattributes_file>..

export ccm_name=""
byref_translate_from_git_repo2ccm_name "${repo_name}" "$project_instance" ccm_name

declare -A repo_submodules_map
if [[ $(echo "${repo_submodules}" | grep "," ) ]]; then
  IFS=","
else
  IFS=" "
fi
for repo_submodule_from_param in $(echo "${repo_submodules}"); do
     repo_submodule_raw_name=$(echo ${repo_submodule_from_param} | awk -F ":" '{print $1}')
     repo_submodules_map["${repo_submodule_raw_name}"]="${repo_submodule_raw_name}"
done
unset repo_submodule_raw_name
unset repo_submodule_from_map
unset IFS

#export project_revisions=`cat ${1}`

if [[ "${BITBUCKET_PROD_USERNAME:-}" != "" && "${BITBUCKET_PROD_PASSWORD:-}" != "" ]]; then
  http_remote_credentials="${BITBUCKET_PROD_USERNAME}:${BITBUCKET_PROD_PASSWORD}@"
else
  http_remote_credentials=""
fi

export git_ssh_remote=ssh://git@${git_server_path}/${repo_name}.git
export git_ssh_remote_orig=ssh://git@${git_server_path}/${repo_name}_orig.git
export git_https_remote=$(echo ${git_ssh_remote} | sed -e "s/ssh:\/\/git@/https:\/\/${http_remote_credentials}/" -e 's/7999/7990\/scm/' | sed -e 's/ssh-//' | sed -e 's/:7990//')
export git_https_remote_orig=$(echo ${git_ssh_remote_orig} | sed -e "s/ssh:\/\/git@/https:\/\/${http_remote_credentials}/" -e 's/7999/7990\/scm/' | sed -e 's/ssh-//' | sed -e 's/:7990//' )
export git_remote_to_use=${git_https_remote}
export git_remote_to_use_orig=${git_https_remote_orig}
echo "Use remote : ${git_remote_to_use} and ${git_remote_to_use_orig}"

function convert_revision(){
    local root_dir=$(pwd)
    local repo_convert_rev_tag=$1

    local tag_to_convert=`git tag | grep "${repo_name}/.*/${repo_convert_rev_tag}$" || grep_ext_value=$?`

    set +x
    if [[ "${tag_to_convert}" == "" ]] ; then
        echo "============================================================================"
        echo " BEGIN: ${repo_convert_rev_tag}"
        echo "============================================================================"
        [[ ${debug:-} == "true" ]] && set -x
    else
        echo "====================================================================================================="
        echo " Already done - skip: ${repo_convert_rev_tag} -> ${tag_to_convert}"
        echo "====================================================================================================="
        [[ ${debug:-} == "true" ]] && set -x
        return
    fi
    local ccm_repo_convert_rev_tag=${repo_convert_rev_tag:: -4}

    local exit_code="0"
    git_4part="${repo_name}~${ccm_repo_convert_rev_tag}:project:${project_instance}"

    ccm_4part=""
    byref_translate_from_git_repo_4part2ccm_4part "${git_4part}" ccm_4part

    find_n_set_baseline_obj_attrs_from_project "${ccm_4part}" "verbose_false" || exit_code=$?
    if [[ "${exit_code}" != "0" ]] ; then
        echo "ERROR: Project not found: ${ccm_4part}"
        exit ${exit_code}
    fi
    local ccm_release=$(echo ${project_release} | cut -d "/" -f 2) # inherited from function find_n_set_baseline_obj_attrs_from_project

    [[ "${ccm_release:-}" == "x" ]] && ( echo "Release is empty!!" &&  exit 1)
    [[ "${ccm_release:-}" == "<void>" ]] && ( echo "Release is <void>!!" &&  exit 1) # if the release is <void> it is rewritten to void as BitBucket does not allow <> chars in tags

    #NOTE: The next line is suppressing the support for having a baseline project with a different name than is being converted: ( and name='${repo_name}' )
    local ccm_baseline_from_tag_info="$(ccm query "is_baseline_project_of('${ccm_4part}') and name='${ccm_name}'" \
                                    -u -f "%version" )" || return 1


    if [[ "${ccm_baseline_from_tag_info}" != "" ]] ; then
        # prefer released if found
        baseline_from_tag_info=""
        byref_translate_from_ccm_version2git_tag "$ccm_baseline_from_tag_info" baseline_from_tag_info

        local repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep ^${repo_name}/.*/${baseline_from_tag_info}_rel$ || grep_ext_value=$? )
        if [[ "${repo_baseline_rev_tag_wcomponent_wstatus}" == "" ]]; then
          local repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep ^${repo_name}/.*/${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$ || grep_ext_value=$? )
          tag_amounts=$(echo ${repo_baseline_rev_tag_wcomponent_wstatus} | wc -l )
          [[ ${tag_amounts} -gt 1 ]] && { printf "ERROR: More than one tag (${tag_amounts}) found in repo_baseline_rev_tag_wcomponent_wstatus\n${repo_baseline_rev_tag_wcomponent_wstatus}\n" && return 1 ;}
        fi
        if [[ "${repo_baseline_rev_tag_wcomponent_wstatus}" == "" ]] ; then
            #find the original tag and convert it first
            local repo_baseline_orig_tag_wstatus=$(git tag | grep "^${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$" || grep_ext_value=$?)
            if [[ "${repo_baseline_orig_tag_wstatus}" != "" ]]; then
                echo "INFO: RECURSIVE action - Wait with ${ccm_repo_convert_rev_tag} / baseline_from_tag_info_wstatus is empty hence the order of tags of the single commit is listed in the wrong order of tags on same commit"
                convert_revision ${repo_baseline_orig_tag_wstatus}
                # reset it to make sure the recursive have not reset it
                local repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep ^${repo_name}/.*/${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$ || grep_ext_value=$? )
                set +x
                echo "============================================================================"
                echo " CONTINUE: ${repo_convert_rev_tag}"
                echo "============================================================================"
                [[ ${debug:-} == "true" ]] && set -x
            else
                echo "ERROR: Dont know why we ended here - something is not right!!"
                echo "The baseline tag that is needed for the conversion of tag: ${repo_convert_rev_tag} cannot even find the tag unconverted: ${baseline_from_tag_info}"
                return 1
            fi
        fi
    else
        local repo_baseline_rev_tag_wcomponent_wstatus="${repo_name}/${repo_init_tag}/${repo_init_tag}"
    fi
    if [[ -f ${execution_root_directory}/${ccm_db}_gitfiles/baseline_history_rewrite.txt ]]; then
      # lookup in the baseline history rewrite file
      repo_baseline_rev_tag_wcomponent_wstatus_lookup=$(grep -E "^${repo_baseline_rev_tag_wcomponent_wstatus}@.+/.+/.+$" ${execution_root_directory}/${ccm_db}_gitfiles/baseline_history_rewrite.txt | cut -d @ -f 2- ) || { echo "INFO: No rewriting baseline found - skip" ; }
      if [[ ${repo_baseline_rev_tag_wcomponent_wstatus_lookup:-} != "" ]]; then
        https_remote_common=$(echo ${git_remote_to_use} | sed -e "s|/${repo_name}.git|/${git_common_target_repo}.git|")
        git fetch ${https_remote_common} -f --no-tags +refs/tags/${repo_baseline_rev_tag_wcomponent_wstatus_lookup}:refs/tags/${repo_baseline_rev_tag_wcomponent_wstatus_lookup} || {
          echo "ERROR: Cannot fetch tag from common remote repo - please investigate"
          exit 1
        }
        repo_baseline_rev_tag_wcomponent_wstatus=${repo_baseline_rev_tag_wcomponent_wstatus_lookup}
      fi
    fi
    repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized=""
    byref_translate_from_ccm_version2git_tag "${repo_baseline_rev_tag_wcomponent_wstatus}" repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized
    echo "repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized=${repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized}"

    local repo_convert_rev_tag_wcomponent_wstatus="${repo_name}/${ccm_release}/${repo_convert_rev_tag}"
    repo_convert_rev_tag_wcomponent_wstatus_gitnormalized=""
    byref_translate_from_ccm_version2git_tag "${repo_convert_rev_tag_wcomponent_wstatus}" repo_convert_rev_tag_wcomponent_wstatus_gitnormalized
    echo "repo_convert_rev_tag_wcomponent_wstatus_gitnormalized=${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}"

    # Get the right content
    if [ `git describe ${repo_convert_rev_tag}`  ] ; then
        # we do have the correct 'content' tag checkout it out
        pwd
        git clean -xffd || git clean -xffd || git clean -xffd # It can happen that the first clean fails, but more tries can fix it
        for path_failed_to_remove in $(git reset -q --hard ${repo_convert_rev_tag} 2>&1 | awk -F "'" '{print $2}'); do
            echo "Reset/remove submodule and it's path: ${path_failed_to_remove}"
            git rm -rf --cached ${path_failed_to_remove}  > /dev/null 2>&1  || echo "never mind"
            rm -rf ${path_failed_to_remove}
        done
    else
        # we do not have the 'content' tag available - investigate its history if it exists ( e.g. missing in repo )
        ./ccm-baseline-history-get-root.sh "${ccm_name}~${ccm_repo_convert_rev_tag}:project:${project_instance}"
        exit 1
    fi

    [[ ${repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized} == "" ]] &&   {
      echo "ERROR: repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized is empty -  something is wrong"
      exit 1
    }
    # Move the workarea pointer to the 'baseline' tag
    git reset -q --mixed ${repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized} > /dev/null 2>&1

    # get the .gitignore files from init commit
    for file in $(git ls-tree --name-only -r ${repo_name}/init/init^{}); do
        git checkout ${repo_name}/init/init $file
        git add ${file}
    done

    exit_code=0
    if [[ ${submodules_from_baseline_obj:-} == true ]] ; then
      ccm_submodules4part="$(ccm query "is_project_in_baseline_of(has_project_in_baseline('${ccm_4part}')) and not ( name='${repo_name}' )" -u -f "%objectname" )" || exit_code=$?
      if [[ $exit_code -ne 0 ]]; then
        if [[ $exit_code -eq 6 ]]; then
          # query did not give outout - try to find the previous release tag via git describe and get setup from there
          # previous _rel
          echo "WARNING: No submodules found.. Restore what was already there from previous previous submodules list and content"
          if git restore .gitmodules ; then
            regex_submodule_line='^160000[[:blank:]]commit[[:blank:]]([0-9a-f]{40})[[:blank:]]+(.+)$'
            IFS=$'\n\r'
            for submodule_line in $(git ls-tree -r HEAD | grep -E '^160000[[:blank:]]+commit[[:blank:]]+[0-9a-f]{40}[[:blank:]]+.+$') ; do
              echo "Process: $submodule_line"
              if [[ ${submodule_line} =~ ${regex_submodule_line} ]] ; then
                local submodule_sha1=${BASH_REMATCH[1]}
                local submodule_path=${BASH_REMATCH[2]}
                git restore ${submodule_path}
                #git update-index --add --replace --cacheinfo "160000,${submodule_sha1},${submodule_path}"
                unset submodule_sha1
                unset submodule_path
              else
                echo skip: $submodule_line
#                cat .gitmodules
#                exit 1
              fi
            done
          else
            echo "INFO: no .gitmodules found"
          fi
        else
          echo "ERROR: Something went wrong"
          exit 1
        fi
      fi
    else
        rm -f .gitmodules
        if [[ ! ${repo_submodules} == "" ]]; then
            touch .gitmodules
        fi
        ccm_submodules4part="$(ccm query "is_member_of('${ccm_4part}') and name!='${ccm_name}' and type='project'" -u -f "%objectname" )" || exit_code=$?
    fi
    if [[ $exit_code -ne 0 ]]; then
      if [[ $exit_code -eq 6 ]]; then
        # query did not give outout
        repo_submodules4part=""
      else
        echo "ERROR: Something went wrong"
        exit 1
      fi
    fi
    IFS=$'\n\r'
    for ccm_submodule4part in ${ccm_submodules4part} ; do
        set +x
        regex_4part='^(.+)~(.+):(.+):(.+)$'
        [[ ${ccm_submodule4part} =~ ${regex_4part} ]] || exit 1
        local ccm_submodule_name=${BASH_REMATCH[1]}
        local ccm_submodule_rev=${BASH_REMATCH[2]}
        local ccm_submodule_inst=${BASH_REMATCH[4]}

        local repo_submodule_name=""
        byref_translate_from_ccm_name2git_repo "$ccm_submodule_name" repo_submodule_name
        local repo_submodule_rev=""
        byref_translate_from_ccm_version2git_tag "$ccm_submodule_rev" repo_submodule_rev

        # Lookup the subproject if present
        repo_submodule=$(echo ${repo_submodules_map[${repo_submodule_name:-}]:-})
        if [[ "${repo_submodule}" == "" ]] ; then
            echo "[INFO]: ${repo_submodule_name} - The subproject not found in projects to add as submodules - skip"
            [[ ${debug:-} == "true" ]] && set -x
            cd ${root_dir}
            continue
        fi
        unset repo_submodule_name
        echo "[INFO]: ${ccm_submodule4part} - use it"
        [[ ${debug:-} == "true" ]] && set -x

        git_remote_submodule_to_use=$(echo ${git_remote_to_use} | sed -e "s/\/${repo_name}.git/\/${repo_submodule}.git/")
        if [[ ${submodules_from_baseline_obj:-} == true ]] ; then
          shared_config_file=$(git ls-tree -r --name-only ${repo_convert_rev_tag} | grep '^.*/shared_config.txt$') || {
            if [[ $? == 1 ]] ; then
              echo "[INFO]: shared_config.txt file not found - ok"
            else
              echo "[ERROR]: Something went wrong in finding the shared_config.txt file"
              exit 1
            fi
          }
          if [[ "${shared_config_file:-}" != "" ]]; then
            echo "[INFO]: shared_config.txt found in the git tag ${repo_convert_rev_tag}"
            if ! git cat-file -p ${repo_convert_rev_tag}:$(git ls-tree -r --name-only ${repo_convert_rev_tag} | grep '^.*/shared_config.txt$' ) | grep -E "^${ccm_submodule_name}~.+$|^\.\.\\\\(.+\\\\)*${ccm_submodule_name}~.+$" ; then
              echo "WARNING: The submodule is not to be found in shared_config_file - fall-back to default"
              _path_from_shared_config_file="."
            else
              # The submodule reference found in shared_config file - convert to unix slashes
              _path_from_shared_config_file=$(dirname $(git cat-file -p ${repo_convert_rev_tag}:$(git ls-tree -r --name-only ${repo_convert_rev_tag} | grep '^.*/shared_config.txt$') \
                                              | grep -E "^${ccm_submodule_name}~.+$|^\.\.\\\\(.+\\\\)*${ccm_submodule_name}~.+$" | sed -e 's/\\/\//g'))
            fi
            if [[ ${_path_from_shared_config_file} == "${ccm_submodule_name}" || ${_path_from_shared_config_file} == "." ]]; then
              echo "The path was not explicitly specified in the shared_config file or module not found - add it to the dir of the shared_config.txt"
              git_submodule_path="$(dirname "${shared_config_file}" | sed -e 's/\\/\//g' )/${repo_submodule}"
            else
              # We found a qualified path for the submodule in the shared_config file
              echo "Use the found path from ${shared_config_file}: ${_path_from_shared_config_file}"
              git_submodule_path="$( realpath -m --relative-to=./ $(dirname ${shared_config_file})/${_path_from_shared_config_file})/${repo_submodule}"
              echo "Set path of submodule to $git_submodule_path in root folder"
            fi
          else
            echo "Place the submodule in the root folder as fall-back"
            git_submodule_path=${repo_submodule}
          fi
        else
          git_submodule_path_in_project=$(ccm finduse -p "${ccm_submodule4part}" | grep "^[[:space:]]" | grep -v '[[:space:]]Projects:' | grep "${ccm_submodule4part//:project:1/''}" | sed -e 's/\t//g' | sed -e 's/\\/\//g' | grep -e "^.*@${ccm_4part//:project:1/''}"'$' | awk -F '~' '{print $1}'  | sed -e "s/^${repo_name}/./g"  | sed -e "s/\/${repo_submodule}//")
          git_submodule_path=${git_submodule_path_in_project}/${repo_submodule}
        fi
        [[ ${git_submodule_path:-} == "" ]] && ( echo "submodule path is empty - exit 1" && exit 1 )

        case ${submodule_update_mode:-} in
            "update-index")
                git add -A . # just add here so execute bit can be manipulated in staged
               # Get the sha1 from a reference / tag or reference is sha1 as not provided
                https_remote_submodule=$(echo ${git_remote_to_use} | sed -e "s/\/me_limited_submodules.git/\/${repo_submodule}.git/")
                export repo_submodule_sha1=$(git ls-remote --tag ${https_remote_submodule} | grep -e "${repo_submodule}/.*/${repo_submodule_rev}_rel$" | awk -F" " '{print $1}')
                # Look then for the "pub" tag
                [[ ${repo_submodule_sha1} == "" ]] && export repo_submodule_sha1=$(git ls-remote --tag ${https_remote_submodule} | grep -e "${repo_submodule}/.*/${repo_submodule_rev}_pub$" | awk -F" " '{print $1}')
                # Accept what is there of remaining
                [[ ${repo_submodule_sha1} == "" ]] && export repo_submodule_sha1=$(git ls-remote --tag ${https_remote_submodule} | grep -e "${repo_submodule}/.*/${repo_submodule_rev}_[dprtis][eueenq][lblsta]$" | awk -F" " '{print $1}')

                [[ ${repo_submodule_sha1} == "" ]] && exit 1

                echo "INFO: Setting submodule: ${repo_submodule} to ${repo_submodule_sha1}"

                echo "INFO: Remove the old dir in git index"
                if [[ ! $(git rm -rf ${repo_submodule} > /dev/null 2>&1 ) ]]; then
                  rm -rf ${repo_submodule}
                fi
                echo "INFO: Add the submodule to .gitmodules"
                git config -f ./.gitmodules --add submodule.${repo_submodule}.path ${repo_submodule}
                git config -f ./.gitmodules --add submodule.${repo_submodule}.url ../${repo_submodule}.git
                git add ./.gitmodules 

                echo "INFO: set the sha1: ${repo_submodule_sha1} as the reference of the submodule: ${repo_submodule}"
                git update-index --add --replace --cacheinfo "160000,${repo_submodule_sha1},${repo_submodule}"
                if [[ ${push_tags_in_submodules} == "true" ]]; then
                    #TODO: if push of tags in submodules is desired
                    exit 1
                    https_url=$(git config --get remote.origin.url | awk -F "/" '{print $3}' | sed -e 's/git@/https:\/\//g' -e 's/7999/7990/')
                    curl https://api.bitbucket.org/2.0/repositories/jdoe/myrepo/refs/tags \
                        -s -u jdoe -X POST -H "Content-Type: application/json" \
                        -d '{ "name" : "new-tag-name", "target" : { "hash" : "a1b2c3d4e5f6" } }'
                fi
                git status | grep "${repo_submodule}"
                cat .gitmodules
                ;;
            "directory")
                if [[ ! $(git rm -rf ${repo_submodule}) ]]; then
                    rm -rf ${repo_submodule}
                    # This should really not be necessary # rm -rf .git/modules/${repo_submodule}
                fi
                if [[ ! $(git submodule update --init --recursive --force ${repo_submodule}) ]] ; then
                     git rm -rf  ${git_submodule_path} --cached || echo "Good already  - never mind"
                     rm -rf  ${git_submodule_path}
                     touch .gitmodules && git add .gitmodules
                     if ! git submodule add --force --name "${repo_submodule}" "../${repo_submodule}.git" "${git_submodule_path}"  ; then
                       cd ${git_submodule_path}
                       git remote -v
                       git status
                       pwd
                       git checkout -B master
                       git reset --hard ${repo_submodule}/${repo_init_tag}/${repo_init_tag} || {
                          git fetch origin +refs/tags/*:refs/tags/*
                          git reset --hard ${repo_submodule}/${repo_init_tag}/${repo_init_tag}
                       }
                       cd ${root_dir}
                       git submodule add --force --name "${repo_submodule}" "../${repo_submodule}.git" "${git_submodule_path}"
                    else
                       git submodule add --force --name "${repo_submodule}" "../${repo_submodule}.git" "${git_submodule_path}"
                    fi
                fi
                git add ./.gitmodules

                cd ${git_submodule_path}

                # Look for the "rel" tag first
                git fetch ${git_remote_submodule_to_use} --tags +refs/heads/*:refs/remotes/origin/*
                git_resolve_tags_wstatus "${repo_submodule}" "${repo_submodule_rev}"
                if [[ "${repo_submodule_rev_wcomponent_wstatus}" == "" ]] ; then
                  echo "[ERROR]: Could find the revision ${repo_submodule}/.*/${repo_submodule_rev}_???"
                  exit 1
                fi

                if [[ ${push_tags_in_submodules} == "true" ]]; then
                    # root project tag handling
                    if [[ ! `git describe ${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}` ]] ; then
                        # it was not found try and fetch to make 100% sure for whatever reason it is not here..
                        git fetch ${git_remote_submodule_to_use} --tags +refs/heads/*:refs/remotes/origin/*
                    fi
                    if [[ `git describe ${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}` ]] ; then
                        # we already have the correct tag, so just set it and move on..
                        git reset -q --hard ${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}
                        git clean -xffd
                        unset repo_submodule_rev
                        unset ccm_submodule_inst
                        cd ${root_dir}
                        continue
                    fi
                fi

                if [ `git describe "${repo_submodule_rev_wcomponent_wstatus}"`  ] ; then
                    # we do have the correct 'content' tag - reset hard to it and make sure we are clean..
                    git clean -xffd
                    git reset -q --hard
                    git reset -q --hard "${repo_submodule_rev_wcomponent_wstatus}"
                    git clean -xffd
                else
                    # we do not have the 'content' tag available - investigate its root
                    cd $(dirname $0)
                    ./ccm-baseline-history-get-root.sh "${ccm_submodule4part})"
                    exit 1
                fi

                if [[ ${push_tags_in_submodules} == "true" ]]; then
                    git tag -f -a -m "Please see tag in master repo for info: ${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}" "${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}"
                    git push ${git_remote_submodule_to_use} --recurse-submodules=no -f "${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}"
                fi

                cd ${root_dir}
                ;;
            *)
                echo "[Submodule-mode] WHY are we here: submodule_update_mode is: ${submodule_update_mode} "
                exit 1
        esac

        unset repo_submodule_rev
        unset repo_submodule_rev_wcomponent_wstatus
        unset ccm_submodule_inst
        unset repo_submodule

    done
    unset IFS
    cd ${root_dir}
    git add -A . > /dev/null 2>&1

    if [[ ! ${repo_submodules} == "" ]]; then
      if [[ -f .gitmodules ]]; then
        cat .gitmodules
        git add .gitmodules
      else
        echo "INFO: No .gitmodules initialized"
      fi
    fi

    git_set_execute_bit_in_index_of_extensions
    git_set_execute_bit_in_index_of_unix_tool_file_executable

    export GIT_COMMITTER_DATE=$(git log -1 --format='%cd' ${repo_convert_rev_tag}) && [[ -z ${GIT_COMMITTER_DATE} ]] && return 1
    export GIT_COMMITTER_NAME=$(git log -1 --format='%cn' ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_NAME} ]] && return 1
    export GIT_COMMITTER_EMAIL=$(git log -1 --format='%ce' ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_EMAIL} ]] && return 1

    export GIT_AUTHOR_DATE=$(git log -1 --format='%ad' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_DATE} ]] && return 1
    export GIT_AUTHOR_NAME=$(git log -1 --format='%an' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_NAME} ]] && return 1
    export GIT_AUTHOR_EMAIL=$(git log -1 --format='%ae' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_EMAIL} ]] && return 1

    echo "git commit content of ${repo_convert_rev_tag}"
    git commit -C ${repo_convert_rev_tag} --reset-author || ( echo "Empty commit.." )

    git submodule status || {
        exit_code=$?
        cat .gitmodules
        exit $exit_code
    }
    git status

    set +x
    echo "#####################"
    echo "# git sizes:"
    echo "#####################"
    [[ -d .git/lfs ]]     && printf "INFO: size: %s %s\n" $(du -sh .git/lfs)
    [[ -d .git/lfs ]]     && printf "INFO: LFS files count in this commit: %s\n" $( git lfs ls-files HEAD | wc -l )
    [[ -d .git/objects ]] && printf "INFO: size: %s %s\n" $(du -sh .git/objects)
    [[ -d .git/modules ]] && printf "INFO: size: %s %s\n" $(du -sh .git/modules)
    echo "#####################"
    [[ ${debug:-} == "true" ]] && set -x

    # reset the committer to get the correct set for the commiting the tag. There is no author of the tag
    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" "${repo_convert_rev_tag}" | awk -F" " '{print $1 " " $2}') && [[ -z ${GIT_AUTHOR_DATE} ]] && return 1
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}
    export GIT_COMMITTER_NAME=$(git tag -l --format="%(taggername)" "${repo_convert_rev_tag}" ) && [[ -z ${GIT_COMMITTER_NAME} ]] && return 1
    export GIT_COMMITTER_EMAIL=$(git tag -l --format="%(taggeremail)" "${repo_convert_rev_tag}" ) && [[ -z ${GIT_COMMITTER_EMAIL} ]] && return 1

    echo "Get tag content of: ${repo_convert_rev_tag}"
    git tag -l --format '%(contents)' "${repo_convert_rev_tag}" > ./tag_meta_data.txt
    echo "git commit content of ${repo_convert_rev_tag}"
    echo "git tag ${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized} based on ${repo_convert_rev_tag}"
    git tag -a -F ./tag_meta_data.txt "${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}"
    rm -f ./tag_meta_data.txt

    # Do not consider submodules
    if [[ ${push_to_remote_during_conversion:-} == "true" ]]; then
        echo "INFO: Configured to push to remote:  git push ${git_remote_to_use} --recurse-submodules=no -f ${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}"
        git push ${git_remote_to_use} --recurse-submodules=no -f "${repo_convert_rev_tag_wcomponent_wstatus_gitnormalized}"
    else
        echo "INFO: Skip push to remote"
    fi

    set +x
    echo "============================================================================"
    echo " DONE: $repo_convert_rev_tag_wcomponent_wstatus"
    echo "============================================================================"
    [[ ${debug:-} == "true" ]] && set -x

    unset GIT_AUTHOR_DATE
    unset GIT_AUTHOR_NAME
    unset GIT_AUTHOR_EMAIL
    unset GIT_COMMITTER_DATE
    unset GIT_COMMITTER_NAME
    unset GIT_COMMITTER_EMAIL
    unset root_dir
    unset tag_to_convert
    unset repo_convert_rev_tag
    unset repo_convert_rev_tag_wcomponent_wstatus
    unset repo_convert_rev_tag_wcomponent_wstatus_gitnormalized
    unset repo_baseline_rev_tag_wcomponent_wstatus
    unset repo_baseline_rev_tag_wcomponent_wstatus_gitnormalized
    unset ccm_repo_convert_rev_tag
    # From subfunction
    unset proj_name
    unset proj_version
    unset proj_instance
    unset project_release
    unset ccm_baseline_obj_and_status_release_this
    unset ccm_baseline_obj
    unset ccm_baseline_status
    unset ccm_baseline_release

}

function reset_converted_tags_except_init_remote_n_local() {
    echo "Delete all local and remote tags '^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$'"
    git tag | grep "^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" | xargs --no-run-if-empty git push ${git_remote_to_use} --delete || echo "Some tags might not be on the remote - never mind"
    git tag | grep "^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" | xargs --no-run-if-empty git tag --delete || echo "Some tags might not be on the remote - never mind"
}

function reset_converted_init_tag_remote_n_local() {
    echo "Delete local and remote tag ${repo_name}/${repo_init_tag}/${repo_init_tag}"
    git tag | grep "^${repo_name}/${repo_init_tag}/${repo_init_tag}$" | xargs --no-run-if-empty git push ${git_remote_to_use} --delete || echo "Some tags might not be on the remote - never mind"
    git tag | grep "^${repo_name}/${repo_init_tag}/${repo_init_tag}$" | xargs --no-run-if-empty git tag --delete || echo "Some tags might not be on the remote - never mind"
}

lock_repo_init_file="${execution_root_directory}/repo_under_construction_lock.txt"

if [[ -f ${lock_repo_init_file} ]]; then
  echo "INFO: Init construction of repo $repo_name did not complete - restart process"
  rm -rf $repo_name
fi

if [[ "${execute_mode}" == "reclone" ]]; then
    echo "INFO: execute_mode is: '${execute_mode}'"
    rm -rf ${repo_name}
fi

if [[ ! -d "${repo_name}" ]] ; then
    #initialize repo
    echo "LOCK Repo: ${repo_name} cloned from: ${git_remote_to_use} is under init construction" > ${lock_repo_init_file}
    git clone ${git_remote_to_use}
    cd ${repo_name}
    git fetch ${git_remote_to_use_orig} --tags --force +refs/heads/*:refs/remotes/origin/*
    git branch -a
    git tag
    git reset -q --hard ${repo_init_tag}
    git clean -xffd

    reset_converted_tags_except_init_remote_n_local
    reset_converted_init_tag_remote_n_local

    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${repo_init_tag} | awk -F" " '{print $1 " " $2}')
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}

    for gitignore_path_n_file in $(echo ${gitignore_path_n_files} | sed -e 's/:/ /g'); do
        gitignore_file_name=`echo ${gitignore_path_n_file} | cut -d "@" -f 1`
        gitignore_rel_path=`echo ${gitignore_path_n_file} | cut -d "@" -f 2`
        gitignore_full_path_name="${execution_root_directory}/${gitignore_file_name}"
        if [[ ! -f ${gitignore_full_path_name} ]]; then
            echo "${gitignore_full_path_name} does not exist.. Current dir:"
            pwd
            echo " .. Consider full path.."
            exit 1
        else
            mkdir -p ${gitignore_rel_path}
            cp ${gitignore_full_path_name} ${gitignore_rel_path}/.gitignore
        fi
    done

    git_initialize_lfs_n_settings
    for gitattributes_path_n_file in $(echo ${gitattributes_path_n_files} | sed -e 's/:/ /g'); do
        gitattributes_file_name=`echo ${gitattributes_path_n_file} | cut -d "@" -f 1`
        gitattributes_rel_path=`echo ${gitattributes_path_n_file} | cut -d "@" -f 2`
        gitattributes_full_path_name="${execution_root_directory}/${gitattributes_file_name}"
        if [[ ! -f ${gitattributes_full_path_name} ]]; then
            echo "${gitattributes_full_path_name} does not exist.. - skip"
        else
            mkdir -p ${gitattributes_rel_path}
            cp ${gitattributes_full_path_name} ${gitattributes_rel_path}/.gitattributes
        fi
    done

    git add -A .
    git status

    echo "git commit init : ${repo_name}/${repo_init_tag}/${repo_init_tag}"
    git commit -C "$repo_init_tag" --amend --reset-author
    echo "git tag init commit: ${repo_name}/${repo_init_tag}/${repo_init_tag}"
    git tag -f -a -m $(git tag -l --format '%(contents)' ${repo_init_tag}) ${repo_name}/${repo_init_tag}/${repo_init_tag}

    unset GIT_AUTHOR_DATE
    unset GIT_COMMITTER_DATE

    git reset -q --hard ${repo_name}/${repo_init_tag}/${repo_init_tag}
    git clean -xffd

    git ls-tree -r ${repo_name}/${repo_init_tag}/${repo_init_tag}

    if [[ ${push_to_remote_during_conversion:-} == "true" ]]; then
        echo "INFO: Configured to push to remote:  git push ${git_remote_to_use} --recurse-submodules=no -f ${repo_name}/${repo_init_tag}/${repo_init_tag}"
        git push ${git_remote_to_use} --recurse-submodules=no -f ${repo_name}/${repo_init_tag}/${repo_init_tag}
    else
        echo "INFO: Skip push to remote: ${git_remote_to_use}"
    fi

    pwd # we are still in the root repo
    echo "UNLOCK repo: ${repo_name} as init construction completed.." && rm -f ${lock_repo_init_file}
else
    echo "Already cloned and initialized"
    cd ${repo_name}
    if [[ "${execute_mode}" == "normal" ]]; then
        echo "INFO: execute_mode is: '${execute_mode}'"
        echo "Reset local tags in scope '^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$' and then start from begin of '^${repo_name}/init/init$'"
        if [[ ! $( git tag | grep -v "^${repo_name}/init/init$" | grep "^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" | xargs --no-run-if-empty git tag --delete ) ]] ; then
          echo "No tags found"
        fi
        git fetch ${git_remote_to_use} --tags --force +refs/heads/*:refs/remotes/origin/*
        git fetch ${git_remote_to_use} -ap +refs/heads/*:refs/remotes/origin/*
    elif [[ "${execute_mode}" == "continue_locally" ]];then
        echo "INFO: execute_mode is: '${execute_mode}'"
        echo "Do not delete already converted tags and fetch again -  just continue in workspace as is"
    elif [[ "${execute_mode}" == "reset_remote_n_local" ]];then
        echo "INFO: execute_mode is: '${execute_mode}'"
        git fetch ${git_remote_to_use} --tags --force +refs/heads/*:refs/remotes/origin/*
        git fetch ${git_remote_to_use} -ap  +refs/heads/*:refs/remotes/origin/*
        reset_converted_tags_except_init_remote_n_local
    fi
    git_initialize_lfs_n_settings
fi

for sha1 in $(git log --topo-order --oneline --all --pretty=format:"%H " | tac) ; do
    echo "Processing: $sha1"
    tags=$(git tag --points-at "${sha1}" | grep -v "^${repo_name}/init/init$" | grep -v "^.*/.*/.*_[dprtis][eueenq][lblsta]$" | grep -v '/' | grep "^.*_[dprtis][eueenq][lblsta]$" || echo "")
    if [[ "${tags}" == "" ]]; then
        converted_tags=$(git tag --points-at "${sha1}" | grep .*/.*/.*_[dprtis][eueenq][lblsta]$ || echo "")
        echo "INFO : No unconverted tags found - These are the new tags found - list and continue"
        echo "${converted_tags}"
        continue
    fi
    for project_revision in $(git tag --points-at "${sha1}" |  grep -v "^${repo_name}/init/init$" | grep -v "^.*/.*/.*_[dprtis][eueenq][lblsta]$" | grep "^.*_[dprtis][eueenq][lblsta]$" || echo "@@@" ); do
        [[ "${repo_name}/${repo_init_tag}/${repo_init_tag}" == "${project_revision}" ]] && continue
        [[ "${repo_init_tag}" == "${project_revision}" ]] && continue
        [[ "@@@" == "${project_revision}" ]] && continue
        convert_revision ${project_revision}
    done
    echo "Done: $sha1"
done

[[ -d .git/lfs ]] && printf "Git LFS in total: %s\n" $( git lfs ls-files --all | wc -l )
[[ -d .git/lfs ]] && echo "Store list of LFS files in: ${execution_root_directory}/git_lfs_files.txt"
[[ -d .git/lfs ]] && git lfs ls-files --all > ${execution_root_directory}/git_lfs_files.txt


