#!/usr/bin/env bash
[[ ${debug:-} == "true" ]] && set -x
[[ ${run_local:-} == "true" ]] && push_remote="false"
set -e
set -u

# Load functions
source ${BASH_SOURCE%/*}/_ccm-functions.sh || source ./_ccm-functions.sh

# parameter $1 is the project list file generated by the baseline_history.sh script
export repo_name=${1}
export repo_init_tag=${2}
export repo_submodules=${3}
[[ submodule_update_mode:-} == "" ]] && export submodule_update_mode="update-index" # or directory which is old style

export gitrepo_project_original=${4}
export project_instance=${5}
export gitignore_file=${6} # FULL PATH

declare -A repo_submodules_map
for repo_submodule_from_map in $(echo "${repo_submodules}"); do
     repo_submodules_map["${repo_submodule_from_map}"]="${repo_submodule_from_map}"
done
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
    else
            echo "====================================================================================================="
            echo " Already done - skip: ${repo_convert_rev_tag} -> ${tag_to_convert}"
            echo "====================================================================================================="
        return
    fi
    [[ ${debug:-} == "true" ]] && set -x
    local ccm_repo_convert_rev_tag=${repo_convert_rev_tag:: -4}

    local exit_code="0"
    find_n_set_baseline_obj_attrs_from_project "${repo_name}~${ccm_repo_convert_rev_tag}:project:${project_instance}" "verbose_false" || exit_code=$?
    if [[ "${exit_code}" != "0" ]] ; then
        echo "ERROR: Project not found: ${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}"
        exit ${exit_code}
    fi
    local ccm_release=$(echo ${project_release} | cut -d "/" -f 2) # inherited from function find_n_set_baseline_obj_attrs_from_project

    [[ "${ccm_release:-}" == "x" ]] && ( echo "Release is empty!!" &&  exit 1)

    local repo_convert_rev_tag_wcomponent_wstatus="${repo_name}/${ccm_release}/${repo_convert_rev_tag}"

    # Get the right content
    if [ `git describe ${repo_convert_rev_tag}`  ] ; then
        # we do have the correct 'content' tag checkout it out
        pwd
        git clean -xffd || git clean -xffd || git clean -xffd # It can happen that the first clean fails, but more tries can fix it
        git reset -q --hard ${repo_convert_rev_tag} || git reset -q --hard ${repo_convert_rev_tag}
    else
        # we do not have the 'content' tag available - investigate its history if it exists ( e.g. missing in repo )
        ./ccm-baseline-history-get-root.sh "${repo_name}~${ccm_repo_convert_rev_tag}:project:${project_instance}"
        exit 1
    fi

    #NOTE: The next line is suppressing the support for having a baseline project with a different name than is being converted: ( and name='${repo_name}' )
    local baseline_from_tag_info=$(ccm query "is_baseline_project_of('${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}') and name='${repo_name}'" \
                                    -u -f "%version" | sed -e 's/ /xxx/g' ) || return 1
    local repo_baseline_rev_tag_wcomponent_wstatus=""
    if [[ "${baseline_from_tag_info}" != "" ]] ; then
        local repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep ^${repo_name}/.*/${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$ || grep_ext_value=$? )
        if [ "${repo_baseline_rev_tag_wcomponent_wstatus}x" == "x" ] ; then
            #find the original tag and convert it first
            baseline_from_tag_info_wstatus=$(git tag | grep "^${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$" || grep_ext_value=$?)
            if [[ "${baseline_from_tag_info_wstatus}" != "" ]]; then
                echo "INFO: RECURSIVE action - Wait with ${ccm_repo_convert_rev_tag} / baseline_from_tag_info_wstatus is empty hence the order of tags of the single commit is listed in the wrong order"
                convert_revision ${baseline_from_tag_info_wstatus}
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

    # Move the workarea pointer to the 'baseline' tag
    git reset --mixed ${repo_baseline_rev_tag_wcomponent_wstatus} >> /dev/null
    git ls-files "*.sh" | xargs git update-index --add --chmod=+x
    git ls-files "*.exe" | xargs git update-index --add --chmod=+x

    git checkout HEAD .gitignore
    rm -f .gitmodules # make sure we have a clean start for every revision - do not use the .gitmodules as we also need to be able to remove some

    local repo_subprojects4part=$(ccm query "is_member_of('${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}') and name!='${repo_name}' and type='project'" -u -f "%objectname" | sed -s 's/ /xxx/g')
    for repo_submodule4part in ${repo_subprojects4part}; do
        regex_4part='^(.+)~(.+):(.+):(.+)$'
        [[ ${repo_submodule4part} =~ ${regex_4part} ]] || exit 1
        local repo_submodule_name=${BASH_REMATCH[1]}
        local repo_submodule_rev=${BASH_REMATCH[2]}
        local repo_submodule_inst=${BASH_REMATCH[4]}

        # Lookup the subproject if present
        repo_submodule=$(echo ${repo_submodules_map[${repo_submodule_name}]})
        if [[ "${repo_submodule}" == "" ]] ; then
            echo "[INFO]: ${repo_submodule_rev} / ${repo_submodule} - The subproject not found in projects to add as submodules - exit"
            cd ${root_dir}
            exit 1
        fi
        echo "[INFO]: ${repo_submodule_rev} / ${repo_submodule} / ${repo_submodule_rev} / ${repo_submodule_inst:1} - use it"

        case ${submodule_update_mode:-} in
            "update-index")
                # Get the sha1 from a reference / tag or reference is sha1 as not provided
                https_remote_submodule=$(echo ${https_remote} | sed -e "s/\/${repo_name}.git/\/${repo_submodule}.git/")
                export repo_submodule_sha1=$(git ls-remote --tag ${https_remote_submodule} | grep -e "${repo_submodule}/.*/${repo_submodule_rev}_rel$" | awk -F" " '{print $1}')
                # Look then for the "pub" tag
                [[ ${repo_submodule_sha1} == "" ]] && export repo_submodule_sha1=$(git ls-remote --tag ${https_remote_submodule} | grep -e "${repo_submodule}/.*/${repo_submodule_rev}_pub$" | awk -F" " '{print $1}')
                # Accept what is there of remaining
                [[ ${repo_submodule_sha1} == "" ]] && export repo_submodule_sha1=$(git ls-remote --tag ${https_remote_submodule} | grep -e "${repo_submodule}/.*/${repo_submodule_rev}_[dprtis][eueenq][lblsta]$" | awk -F" " '{print $1}')

                [[ ${repo_submodule_sha1} == "" ]] && exit 1

                echo "INFO: Setting submodule: ${repo_submodule} to ${repo_submodule_sha1}"

                # Add the submodule
                git config -f ./.gitmodules --add submodule.code-utils.path ${repo_submodule}
                git config -f ./.gitmodules --add submodule.code-utils.url ../${repo_submodule}.git

                # set the sha1 as the reference of the submodule
                git update-index --add --cacheinfo 160000,${repo_submodule_sha1},${repo_submodule}
                if [[ ${push_tags_in_submodules} == "true" ]]; then
                    https_url=$(git config --get remote.origin.url | awk -F "/" '{print $3}' | sed -e 's/git@/https:\/\//g' -e 's/7999/7990/')
                    curl https://api.bitbucket.org/2.0/repositories/jdoe/myrepo/refs/tags \
                        -s -u jdoe -X POST -H "Content-Type: application/json" \
                        -d '{ "name" : "new-tag-name", "target" : { "hash" : "a1b2c3d4e5f6" } }'
                fi
                exit 1
                ;;
            "directory")
                # Look for the "rel" tag first
                export repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_rel$ || grep_exit=$? )
                # Look then for the "pub" tag
                [[ ${repo_submodule_rev_wcomponent_wstatus} == "" ]] && export repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_pub$ || grep_exit=$? )
                # Accept what is there of remaining
                [[ ${repo_submodule_rev_wcomponent_wstatus} == "" ]] && export repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_[dprtis][eueenq][lblsta]$ || grep_exit=$? )

                checkout_exit=0
                git checkout HEAD ${repo_submodule} || checkout_exit=$?
                if [[ ${checkout_exit} -ne 0 ]] ; then
                    ls -la ${repo_submodule} || ls_la_exit=$? # just for info / debug
                    if [[ ! $(git rm -rf ${repo_submodule}) ]]; then
                        rm -rf ${repo_submodule}
                        # This should really not be necessary # rm -rf .git/modules/${repo_submodule}
                    fi
                    git clean -xffd
                    git checkout HEAD ${repo_submodule} || git submodule add --force ../${repo_submodule}.git ${repo_submodule} || git submodule add --force ../${repo_submodule}.git ${repo_submodule}
                fi
                git clean -xffd
                if [[ ! $(git submodule update --init --recursive --force ${repo_submodule}) ]] ; then
                     git rm -rf ${repo_submodule} --cached
                     rm -rf ${repo_submodule}
                     git submodule add --force ../${repo_submodule}.git ${repo_submodule} || git submodule add --force ../${repo_submodule}.git ${repo_submodule} # try harder
                     git submodule update --init --recursive --force ${repo_submodule}
                fi

                cd ${repo_submodule}

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

                # Look for the "rel" tag first
                repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_rel$ || grep_exit=$? )
                # Look then for the "pub" tag
                [[ ${repo_submodule_rev_wcomponent_wstatus} == "" ]] && repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_pub$ || grep_exit=$? )
                # Accept what is there of remaining
                [[ ${repo_submodule_rev_wcomponent_wstatus} == "" ]] && repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_[dprtis][eueenq][lblsta]$ || grep_exit=$? )

                if [ `git describe ${repo_submodule_rev_wcomponent_wstatus}`  ] ; then
                    # we do have the correct 'content' tag - reset hard to it and make sure we are clean..
                    git clean -xffd
                    git reset --hard HEAD
                    git reset --hard ${repo_submodule_rev_wcomponent_wstatus}
                    git clean -xffd
                else
                    # we do not have the 'content' tag available - investigate its root
                    cd $(dirname $0)
                    ./ccm-baseline-history-get-root.sh "${repo_submodule}~$(echo ${repo_submodule_rev} | sed -e 's/xxx/ /g')"
                    exit 1
                fi

                git tag -f -a -m "Please see tag in master repo for info: ${repo_convert_rev_tag_wcomponent_wstatus}" ${repo_convert_rev_tag_wcomponent_wstatus}

                [[ ${push_remote:-} == "true" ]] && git push origin --recurse-submodules=no -f ${repo_convert_rev_tag_wcomponent_wstatus}
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
        cd ${root_dir}

    done
    cd ${root_dir}
    git add  --chmod=+x -A . >> /dev/null

    export GIT_COMMITTER_DATE=$(git log -1 --format='%cd' ${repo_convert_rev_tag}) && [[ -z ${GIT_COMMITTER_DATE} ]] && return 1
    export GIT_COMMITTER_NAME=$(git log -1 --format='%cn' ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_NAME} ]] && return 1
    export GIT_COMMITTER_EMAIL=$(git log -1 --format='%ce' ${repo_convert_rev_tag} ) && [[ -z ${GIT_COMMITTER_EMAIL} ]] && return 1

    export GIT_AUTHOR_DATE=$(git log -1 --format='%ad' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_DATE} ]] && return 1
    export GIT_AUTHOR_NAME=$(git log -1 --format='%an' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_NAME} ]] && return 1
    export GIT_AUTHOR_EMAIL=$(git log -1 --format='%ae' ${repo_convert_rev_tag} ) && [[ -z ${GIT_AUTHOR_EMAIL} ]] && return 1

    echo "git commit content of ${repo_convert_rev_tag}"
    git commit -q -C ${repo_convert_rev_tag} --reset-author || ( echo "Empty commit.." )

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
    if [[ ${push_remote:-} == "true" ]]; then
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

#initialize repo
if [ ! -e ${repo_name} ] ; then
    git clone --recursive -b master ${git_remote_repo}
    cd ${repo_name}
    git branch -a
    git tag
    git reset -q --hard ${repo_init_tag}
    git clean -xffd

    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${repo_init_tag} | awk -F" " '{print $1 " " $2}')
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}

    test "${gitignore_file}x" != "x" && test ! -e ${gitignore_file} && echo "${gitignore_file} does not exist.. Current dir:" && pwd && echo " .. Consider full path.." && exit 1
    test "${gitignore_file}x" != "x" && test -e ${gitignore_file} && cp ${gitignore_file} ./.gitignore

    git status
    git add -A .
    git status

    git commit -C "$repo_init_tag" --amend --reset-author
    git tag -f -a -m $(git tag -l --format '%(contents)' ${repo_init_tag}) ${repo_name}/${repo_init_tag}/${repo_init_tag}

    unset GIT_AUTHOR_DATE
    unset GIT_COMMITTER_DATE

    git reset -q --hard ${repo_name}/${repo_init_tag}/${repo_init_tag}
    git clean -xffd
    pwd
    # we are still in the root repo
else
    echo "Already cloned and initialized"
    echo "Reset all tags to remote"
    cd ${repo_name}
    git tag | grep -v "^${repo_name}/init/init$" | grep "^${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" |  xargs git tag --delete
    git fetch --tags
    pwd
fi

set +x
export project_revisions=$(for tag in $(git log --topo-order --oneline --all --decorate \
                                    | grep -e '(tag: ' \
                                    | awk -F"(" '{print $2}' \
                                    | awk -F")" '{print $1}' \
                                    | sed -e 's/,//g' \
                                    | sed -e 's/tag://g' \
                                    | sed -e 's/HEAD -> master//g' \
                            ); do \
                                echo $tag ; \
                            done \
                            | grep -v origin/master$ \
                            | grep -v origin/HEAD$ \
                            | grep -v ${repo_name}/${repo_init_tag}/${repo_init_tag}$ \
                            | grep -v .*/.*/.*_[dprtis][eueenq][lblsta]$ \
                            | grep -v ${repo_init_tag}$ \
                            | tac \
                           )


echo "Found project revisions/tags:"
rm -f project_tags.txt && touch project_tags.txt
for project_revision in ${project_revisions}; do
    echo $project_revision >> project_tags.txt
done
cat ./project_tags.txt && rm -f ./project_tags.txt
[[ ${debug:-} == "true" ]] && set -x

echo "Do the conversions"
for project_revision in ${project_revisions}; do
    convert_revision ${project_revision}
done
