#!/usr/bin/env bash
[[ ${debug:-} == "true" ]] && set -x
[[ ${run_local:-} == "true" ]] && push_remote="false"
set -e
set -u

# Load functions
source ${BASH_SOURCE%/*}/_ccm-functions.sh || source ./_ccm-functions.sh
source ${BASH_SOURCE%/*}/_git-functions.sh || source ./_git-functions.sh

# parameter $1 is the project list file generated by the baseline_history.sh script
export repo_name=${1}
export repo_init_tag=${2}
export repo_submodules=${3}
[[ ${submodule_update_mode:-} == "" ]] && export submodule_update_mode="directory" # or update-index which is old style
[[ ${push_tags_in_submodules:-} == "" ]] && export push_tags_in_submodules="false"
[[ "${execute_mode:-}" == "" ]] && export execute_mode="normal"

export gitrepo_project_original=${4}
export project_instance=${5}
export gitignore_file=${6} # FULL PATH
export gitattributes_file=${7} # FULL PATH

declare -A repo_submodules_map
for repo_submodule_from_param in $(echo "${repo_submodules}"); do
     repo_submodule_raw_name=$(echo ${repo_submodule_from_param} | awk -F ":" '{print $1}')
     repo_submodules_map["${repo_submodule_from_param}"]="${repo_submodule_raw_name}"
done
unset repo_submodule_raw_name
unset repo_submodule_from_map

#export project_revisions=`cat ${1}`

export git_remote_repo=ssh://git@${git_server_path}/${repo_name}.git

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
    find_n_set_baseline_obj_attrs_from_project "${repo_name}~${ccm_repo_convert_rev_tag}:project:${project_instance}" "verbose_false" || exit_code=$?
    if [[ "${exit_code}" != "0" ]] ; then
        echo "ERROR: Project not found: ${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}"
        exit ${exit_code}
    fi
    local ccm_release=$(echo ${project_release} | cut -d "/" -f 2) # inherited from function find_n_set_baseline_obj_attrs_from_project

    [[ "${ccm_release:-}" == "x" ]] && ( echo "Release is empty!!" &&  exit 1)

    #NOTE: The next line is suppressing the support for having a baseline project with a different name than is being converted: ( and name='${repo_name}' )
    local baseline_from_tag_info=$(ccm query "is_baseline_project_of('${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}') and name='${repo_name}'" \
                                    -u -f "%version" | sed -e 's/ /xxx/g' ) || return 1
    if [[ "${baseline_from_tag_info}" != "" ]] ; then
        local repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep ^${repo_name}/.*/${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$ || grep_ext_value=$? )
        if [ "${repo_baseline_rev_tag_wcomponent_wstatus}x" == "x" ] ; then
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

    local repo_convert_rev_tag_wcomponent_wstatus="${repo_name}/${ccm_release}/${repo_convert_rev_tag}"

    # Get the right content
    if [ `git describe ${repo_convert_rev_tag}`  ] ; then
        # we do have the correct 'content' tag checkout it out
        pwd
        git clean -xffd || git clean -xffd || git clean -xffd # It can happen that the first clean fails, but more tries can fix it
        for path_failed_to_remove in $(git reset -q --hard ${repo_convert_rev_tag} 2>&1 | awk -F "'" '{print $2}'); do
            git rm -rf ${path_failed_to_remove}  > /dev/null 2>&1  || rm -rf ${path_failed_to_remove}
        done
    else
        # we do not have the 'content' tag available - investigate its history if it exists ( e.g. missing in repo )
        ./ccm-baseline-history-get-root.sh "${repo_name}~${ccm_repo_convert_rev_tag}:project:${project_instance}"
        exit 1
    fi

    [[ ${repo_baseline_rev_tag_wcomponent_wstatus} == "" ]] &&  exit 1
    # Move the workarea pointer to the 'baseline' tag
    git reset -q --mixed ${repo_baseline_rev_tag_wcomponent_wstatus} > /dev/null 2>&1

    git checkout HEAD .gitignore
    git add ./.gitignore

    git checkout HEAD ./.gitattributes
    git add ./.gitattributes

    rm -f .gitmodules
    if [[ ! ${repo_submodules} == "" ]]; then
        touch .gitmodules && git add ./.gitmodules # make sure we have a clean start for every revision - do not use the .gitmodules as we also need to be able to remove some
    fi

    local repo_subprojects4part=$(ccm query "is_member_of('${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}') and name!='${repo_name}' and type='project'" -u -f "%objectname" | sed -s 's/ /xxx/g')
    for repo_submodule4part in ${repo_subprojects4part}; do
        set +x
        regex_4part='^(.+)~(.+):(.+):(.+)$'
        [[ ${repo_submodule4part} =~ ${regex_4part} ]] || exit 1
        local repo_submodule_name=${BASH_REMATCH[1]}
        local repo_submodule_rev=${BASH_REMATCH[2]}
        local repo_submodule_inst=${BASH_REMATCH[4]}

        # Lookup the subproject if present
        repo_submodule=$(echo ${repo_submodules_map[${repo_submodule_name:-}]:-})
        if [[ "${repo_submodule}" == "" ]] ; then
            echo "[INFO]: ${repo_submodule_name} - The subproject not found in projects to add as submodules - skip"
            [[ ${debug:-} == "true" ]] && set -x
            cd ${root_dir}
            continue
        fi
        echo "[INFO]: ${repo_submodule4part} - use it"
        [[ ${debug:-} == "true" ]] && set -x

        case ${submodule_update_mode:-} in
            "update-index")
                git add -A . # just add here so execute bit can be manipulated in staged
               # Get the sha1 from a reference / tag or reference is sha1 as not provided
                https_remote_submodule=$(echo ${https_remote} | sed -e "s/\/me_limited_submodules.git/\/${repo_submodule}.git/")
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
                     git rm -rf ${repo_submodule} --cached || echo "Good already  - never mind"
                     rm -rf ${repo_submodule}
                     git submodule add --force ../${repo_submodule}.git ${repo_submodule} || git submodule add --force ../${repo_submodule}.git ${repo_submodule} # try harder
                     git submodule update --init --recursive --force ${repo_submodule}
                fi
                git add ./.gitmodules

                cd ${repo_submodule}

                # Look for the "rel" tag first
                git_resolve_tags_wstatus "${repo_submodule}" "${repo_submodule_rev}"
                if [[ "${repo_submodule_rev_wcomponent_wstatus}" == "" ]] ; then
                    # try and update
                    git fetch --tags
                    git_resolve_tags_wstatus "${repo_submodule}" "${repo_submodule_rev}"
                    if [[ "${repo_submodule_rev_wcomponent_wstatus}" == "" ]] ; then
                        echo "[ERROR]: Could find the revision ${repo_submodule_rev} for the ${repo_submodule}"
                        exit 1
                    fi
                fi

                if [[ ${push_tags_in_submodules} == "true" ]]; then
                    # root project tag handling
                    if [[ ! `git describe ${repo_convert_rev_tag_wcomponent_wstatus}` ]] ; then
                        # it was not found try and fetch to make 100% sure for whatever reason it is not here..
                        git fetch --tags
                    fi
                    if [[ `git describe ${repo_convert_rev_tag_wcomponent_wstatus}` ]] ; then
                        # we already have the correct tag, so just set it and move on..
                        git reset --hard ${repo_convert_rev_tag_wcomponent_wstatus}
                        git clean -xffd
                        unset repo_submodule_rev
                        unset repo_submodule_inst
                        cd ${root_dir}
                        continue
                    fi
                fi

                if [ `git describe "${repo_submodule_rev_wcomponent_wstatus}"`  ] ; then
                    # we do have the correct 'content' tag - reset hard to it and make sure we are clean..
                    git clean -xffd
                    git reset --hard HEAD
                    git reset --hard "${repo_submodule_rev_wcomponent_wstatus}"
                    git clean -xffd
                else
                    # we do not have the 'content' tag available - investigate its root
                    cd $(dirname $0)
                    ./ccm-baseline-history-get-root.sh "${repo_submodule}~$(echo ${repo_submodule_rev} | sed -e 's/xxx/ /g')"
                    exit 1
                fi

                if [[ ${push_tags_in_submodules} == "true" ]]; then
                    git tag -f -a -m "Please see tag in master repo for info: ${repo_convert_rev_tag_wcomponent_wstatus}" ${repo_convert_rev_tag_wcomponent_wstatus}
                    git push origin --recurse-submodules=no -f ${repo_convert_rev_tag_wcomponent_wstatus}
                fi

                cd ${root_dir}
                ;;
            *)
                echo "[Submodule-mode] WHY are we here: submodule_update_mode is: ${submodule_update_mode} "
                exit 1
        esac

        unset repo_submodule_name
        unset repo_submodule_rev
        unset repo_submodule_rev_wcomponent_wstatus
        unset repo_submodule_inst
        unset repo_submodule

    done
    cd ${root_dir}
    git add -A . > /dev/null 2>&1
    if [[ ! ${repo_submodules} == "" ]]; then
        cat .gitmodules
        git add .gitmodules
        for repo_submodule_from_param in $(echo "${repo_submodules}"); do
            git status | grep ${repo_submodule_from_param} || echo "${repo_submodule_from_param} - Not in use in this revision"
        done
        git add .gitmodules
        git submodule status
    fi
    git ls-files "*.sh" | xargs --no-run-if-empty -d '\n' git update-index --add --chmod=+x
    git ls-files "*.exe" | xargs --no-run-if-empty -d '\n' git update-index --add --chmod=+x
    git add -A .

    export GIT_COMMITTER_DATE=$(git log -1 --format='%cd' ${repo_convert_rev_tag}) && [[ -z ${GIT_COMMITTER_DATE} ]] && return 1
    export GIT_COMMITTER_NAME=$(git log -1 --format='%cn' ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_NAME} ]] && return 1
    export GIT_COMMITTER_EMAIL=$(git log -1 --format='%ce' ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_EMAIL} ]] && return 1

    export GIT_AUTHOR_DATE=$(git log -1 --format='%ad' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_DATE} ]] && return 1
    export GIT_AUTHOR_NAME=$(git log -1 --format='%an' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_NAME} ]] && return 1
    export GIT_AUTHOR_EMAIL=$(git log -1 --format='%ae' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_EMAIL} ]] && return 1

    echo "git commit content of ${repo_convert_rev_tag}"
    git commit -q -C ${repo_convert_rev_tag} --reset-author || ( echo "Empty commit.." )

    git submodule status

    # reset the committer to get the correct set for the commiting the tag. There is no author of the tag
    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${repo_convert_rev_tag} | awk -F" " '{print $1 " " $2}') && [[ -z ${GIT_AUTHOR_DATE} ]] && return 1
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}
    export GIT_COMMITTER_NAME=$(git tag -l --format="%(taggername)" ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_NAME} ]] && return 1
    export GIT_COMMITTER_EMAIL=$(git tag -l --format="%(taggeremail)" ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_EMAIL} ]] && return 1

    echo "Get tag content of: ${repo_convert_rev_tag}"
    git tag -l --format '%(contents)' ${repo_convert_rev_tag} > ./tag_meta_data.txt
    echo "git commit content of ${repo_convert_rev_tag}"
    echo "git tag ${repo_convert_rev_tag_wcomponent_wstatus} based on ${repo_convert_rev_tag}"
    git tag -a -F ./tag_meta_data.txt ${repo_convert_rev_tag_wcomponent_wstatus}
    rm -f ./tag_meta_data.txt

    # Do not consider submodules
    if [[ ${push_to_remote_during_conversion:-} == "true" ]]; then
        echo "INFO: Configured to push to remote:  git push origin --recurse-submodules=no -f ${repo_convert_rev_tag_wcomponent_wstatus}"
        git push origin --recurse-submodules=no -f ${repo_convert_rev_tag_wcomponent_wstatus}
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
    unset repo_baseline_rev_tag_wcomponent_wstatus
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

function reset_converted_tags_remote_n_local() {
    echo "Delete fetch all tags and delete all the '^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$' tags on the remote and local to restart except ${repo_name}/init/init"
    git tag | grep -v "^${repo_name}/init/init$" | grep "^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" | xargs --no-run-if-empty git push origin --delete || echo "Some tags might not be on the remote - never mind"
    git tag | grep -v "^${repo_name}/init/init$" | grep "^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" | xargs --no-run-if-empty git tag --delete
}

#initialize repo
if [ ! -e ${repo_name} ] ; then
    git clone -b master ${git_remote_repo}
    cd ${repo_name}
    git branch -a
    git tag
    git reset -q --hard ${repo_init_tag}
    git clean -xffd

    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${repo_init_tag} | awk -F" " '{print $1 " " $2}')
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}

    if [[ "${gitignore_file}" != "x" ]]; then
        if [[ ! -e ${gitignore_file} ]]; then
            echo "${gitignore_file} does not exist.. Current dir:"
            pwd
            echo " .. Consider full path.."
            exit 1
        fi
    fi
    if [[ "${gitignore_file}x" != "x" ]]; then
        if [[ -e ${gitignore_file} ]]; then
            cp ${gitignore_file} ./.gitignore
        fi
    fi

    if [[ -e "${gitattributes_file}" ]]; then
        cp ${gitattributes_file} ./.gitattributes
    else
        echo "${gitattributes_file} does not exist.. skip"
    fi

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

    if [[ "${execute_mode}" == "reset_remote_n_local" ]];then
        echo "execute_mode is: '${execute_mode}'"
        reset_converted_tags_remote_n_local
    fi
    echo "Installing Git LFS for the repo"
    git lfs install
    pwd # we are still in the root repo
else
    echo "Already cloned and initialized"
    cd ${repo_name}
    if [[ "${execute_mode}" == "normal" ]]; then
        echo "execute_mode is: '${execute_mode}'"
        echo "Reset local tags in scope '^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$' and then start from begin of '^${repo_name}/init/init$'"
        git tag | grep -v "^${repo_name}/init/init$" | grep "^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" | xargs --no-run-if-empty git tag --delete
        git fetch --tags
        git fetch -ap
    elif [[ "${execute_mode}" == "continue_locally" ]];then
        echo "execute_mode is: '${execute_mode}'"
        echo "Do not delete already converted tags and fetch again -  just continue in workspace as is"
    elif [[ "${execute_mode}" == "reset_remote_n_local" ]];then
        echo "execute_mode is: '${execute_mode}'"
        git fetch --tags --force
        git fetch -ap
        reset_converted_tags_remote_n_local
    fi
fi

export https_remote=$(git config --get remote.origin.url | sed -e 's/ssh:\/\/git@/https:\/\//' -e 's/7999/7990\/scm/')
echo "Calculating https remote from ssh origin: ${https_remote}"

for sha1 in $(git log --topo-order --oneline --all --pretty=format:"%H " | tac) ; do
    echo "Processing: $sha1"
    tags=$(git tag --points-at "${sha1}" | grep -v .*/.*/.*_[dprtis][eueenq][lblsta]$ || echo "")
    if [[ "${tags}" == "" ]]; then
        converted_tags=$(git tag --points-at "${sha1}" | grep .*/.*/.*_[dprtis][eueenq][lblsta]$ || echo "")
        echo "INFO : No unconverted tags found - These are the new tags found - list and continue"
        echo "${converted_tags}"
        continue
    fi
    for project_revision in $(git tag --points-at "${sha1}" | grep -v .*/.*/.*_[dprtis][eueenq][lblsta]$ || echo "@@@" ); do
        [[ "${repo_name}/${repo_init_tag}/${repo_init_tag}" == "${project_revision}" ]] && continue
        [[ "${repo_init_tag}" == "${project_revision}" ]] && continue
        [[ "@@@" == "${project_revision}" ]] && continue
        convert_revision ${project_revision}
    done
    echo "Done: $sha1"
done

exit
