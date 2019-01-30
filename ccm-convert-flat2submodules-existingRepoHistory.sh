#!/usr/bin/env bash
set -e
set -x

# parameter $1 is the project list file generated by the baseline_history.sh script
export repo_name=${1}
export repo_init_tag=${2}
export repo_submodules=${3}
export gitrepo_project_original=${4}
export project_instance=${5}
export gitignore_file=${6} # FULL PATH

#export project_revisions=`cat ${1}`

export gitrepo_project_original=${gitrepo_project_original}
export gitrepo_project_submodule=${gitrepo_project_original}
export git_remote=git-unisource.md-man.biz:7999
export git_remote_repo=ssh://git@${git_remote}/${gitrepo_project_original}/${repo_name}.git

function convert_revision(){
    repo_convert_rev_tag=$1
    set +x

    repo_convert_rev_tag_wcomponent_wstatus=`git tag | grep "${repo_name}/.*/${repo_convert_rev_tag}$" || grep_ext_value=$?`

    if [[ "${repo_convert_rev_tag_wcomponent_wstatus}" == "" ]] ; then
            echo "============================================================================"
            echo " BEGIN: $repo_convert_rev_tag_wcomponent_wstatus"
            echo "============================================================================"
        set -x
    else
            echo "============================================================================"
            echo " Already done - skip: $repo_convert_rev_tag_wcomponent_wstatus"
            echo "============================================================================"
        set -x
        continue
    fi
    ccm_repo_convert_rev_tag=${repo_convert_rev_tag:: -4}

    ccm_baseline_obj_this=$(ccm query "has_project_in_baseline('${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}') and release='$(ccm query "name='${repo_name}' and version='$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g')' and type='project'" -u -f "%release")'" -u -f "%objectname" | head -1 )
    ccm_component_release=`ccm attr -show release "${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}" | sed -e 's/ //g'`
    ccm_release=$(echo ${ccm_component_release} | cut -d "/" -f 2)

    test "${ccm_release}x" == "x" && ( echo "Release is empty!!" &&  exit 1)

    local repo_convert_rev_tag_wcomponent_wstatus="${repo_name}/${ccm_release}/${repo_convert_rev_tag}"

    # Get the right content
    if [ `git describe ${repo_convert_rev_tag}`  ] ; then
        # we do have the correct 'content' tag checkout it out
        git reset -q --hard ${repo_convert_rev_tag}
    else
        # we do not have the 'content' tag available - investigate its history if it exists ( e.g. missing in repo )
        ./ccm-baseline-history-get-root.sh "${repo_name}~${ccm_repo_convert_rev_tag}:project:${project_instance}"
        exit 1
    fi

    git clean -xffd >> /dev/null

    #NOTE: The next line is suppressing the support for having a baseline project with a different name than is being converted: ( and name='${repo_name}' )
    local baseline_from_tag_info=$(ccm query "is_baseline_project_of('${repo_name}~$(echo ${repo_convert_rev_tag:: -4}| sed -e 's/xxx/ /g'):project:${project_instance}') and name='${repo_name}'" \
                                    -u -f "%version" | sed -e 's/ /xxx/g' )
    if [ "${baseline_from_tag_info}X" != "X" ] ; then
        local repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep "${repo_name}/.*/${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$" || grep_ext_value=$? )
        if [ "${repo_baseline_rev_tag_wcomponent_wstatus}x" == "x" ] ; then
            #find the original tag and convert it first
            baseline_from_tag_info_wstatus=$(git tag | grep "^${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$")
            if [ "${baseline_from_tag_info_wstatus}x" != "x" ]; then
                convert_revision ${baseline_from_tag_info_wstatus}
                local baseline_from_tag_info=$(git show ${repo_convert_rev_tag} | grep "1) ${repo_name}~" | awk -F"~" '{print $2}')
                local repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep "${repo_name}/.*/${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$" || grep_ext_value=$? )
                if [ "${repo_baseline_rev_tag_wcomponent_wstatus}x" == "x" ] ; then
                    local repo_baseline_rev_tag_wcomponent_wstatus="${repo_name}/${repo_init_tag}/${repo_init_tag}"
                fi
            else
                echo "ERROR: Dont know why we ended here - something is not right!!"
                echo "The baseline tag that is needed for the conversion of tag: ${repo_convert_rev_tag:: -4} cannot even find the tag unconverted: ${baseline_from_tag_info}"
                exit 1
            fi
        fi
    else
        local repo_baseline_rev_tag_wcomponent_wstatus="${repo_name}/${repo_init_tag}/${repo_init_tag}"
    fi

    # Move the workarea pointer to the 'baseline' tag
    git reset --mixed ${repo_baseline_rev_tag_wcomponent_wstatus} >> /dev/null
    git checkout HEAD .gitignore
    git checkout HEAD .gitmodules || echo ".gitmodules does not exist in current revision"

    for repo_submodule in ${repo_submodules}; do
        local repo_submodule_rev_inst=$(ccm query " \
                                   hierarchy_project_members(\
                                       '${ccm_project_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${project_instance}',none \
                                   ) \
                                   and name='${repo_submodule}'" -u -f "%version:%instance" | sed -s 's/ /xxx/g')
        if [ "${repo_submodule_rev_inst}X" == "X" ] ; then
            echo "The submodule does not exit as a project - skip"
            continue
        fi
        local repo_submodule_rev=$(echo ${repo_submodule_rev_inst} | awk -F ":" '{print $1}')
        local repo_submodule_inst=$(echo ${repo_submodule_rev_inst} | awk -F ":" '{print $2}') # not used currently - for debugging per
        if [ ! `git checkout HEAD ${repo_submodule} || git checkout HEAD ${repo_submodule}` ] ; then
                git rm -rf ${repo_submodule} || ( rm -rf ${repo_submodule} ; rm -rf .git/modules/${repo_submodule} )
                git submodule add --force ../${repo_submodule}.git || git submodule add --force ../${repo_submodule}.git
        fi
        git submodule update --init --recursive ${repo_submodule}

        cd ${repo_submodule}

        git fetch --tags

        if [ `git describe ${repo_convert_rev_tag_wcomponent_wstatus}` ] ; then
            # we already have the correct tag, so just set it and move on..
            git checkout ${repo_convert_rev_tag_wcomponent_wstatus}
            git clean -xffd
            unset repo_submodule_rev
            unset repo_submodule_inst
            cd -
            continue
        fi


        repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_[dprtis][eueenq][lblsta]$ || grep_exit=$? )

        if [ `git describe ${repo_submodule_rev_wcomponent_wstatus}`  ] ; then
            # we do have the correct 'content' tag - checkout it out
            git checkout ${repo_submodule_rev_wcomponent_wstatus}
            git clean -xffd
        else
            # we do not have the 'content' tag available - investigate its root
            cd $(dirname $0)
            ./ccm-baseline-history-get-root.sh "${repo_submodule}~$(echo ${repo_submodule_rev:: -4} | sed -e 's/xxx/ /g')"
            exit 1
        fi

        git tag -f -a -m "Please see tag in master repo for info: ${repo_convert_rev_tag_wcomponent_wstatus}" \
                            ${repo_convert_rev_tag_wcomponent_wstatus}

        git push origin -f --tag ${repo_convert_rev_tag_wcomponent_wstatus}

        unset repo_submodule_rev
        unset repo_submodule_rev_wcomponent_wstatus
        unset repo_submodule_inst
        cd -

    done
    git add -A . >> /dev/null

    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${repo_convert_rev_tag} | awk -F" " '{print $1 " " $2}')
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}

    git commit -q -C ${repo_convert_rev_tag} --reset-author || ( echo "Empty commit.." )

    git tag -l --format '%(contents)' ${repo_convert_rev_tag} > ./tag_meta_data.txt
    git tag -a -F ./tag_meta_data.txt ${repo_convert_rev_tag_wcomponent_wstatus}
    rm -f ./tag_meta_data.txt


    git push origin -f --tag ${repo_convert_rev_tag_wcomponent_wstatus}

set +x
    echo "============================================================================"
    echo " DONE: $repo_convert_rev_tag_wcomponent_wstatus"
    echo "============================================================================"
set -x

    unset GIT_AUTHOR_DATE
    unset GIT_COMMITTER_DATE
    unset repo_convert_rev_tag_wcomponent_wstatus
    unset repo_baseline_rev_tag_wcomponent_wstatus

}

#initialize repo
if [ ! -e ${repo_name} ] ; then
    git clone --recursive -b master ${git_remote_repo}
    cd ${repo_name}
    git branch -a
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
    git tag -a -m $(git tag -l --format '%(contents)' ${repo_init_tag}) ${repo_name}/${repo_init_tag}/${repo_init_tag}

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
    git tag | grep "${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" |  xargs git tag --delete
    git fetch --tags
    pwd
fi

set +x
export project_revisions=$(for tag in $(git log --topo-order --oneline --all --decorate \
                                    | awk -F"(" '{print $2}' \
                                    | awk -F")" '{print $1}' \
                                    | sed -e 's/,//g' \
                                    | sed -e 's/tag://g' \
                                    | sed -e 's/HEAD -> master//g' \
                            ); do \
                                echo $tag ; \
                            done \
                            | grep -v origin/ \
                            | grep -v HEAD \
                            | grep -v master \
                            | grep -v ${repo_name}/${repo_init_tag}$ \
                            | grep -v ${repo_name}/${repo_init_tag}/${repo_init_tag}$ \
                            | grep -v .*/.*/.*_[dprtis][eueenq][lblsta]$ \
                            | grep -v ${repo_init_tag}$ \
                            | tac \
                           )

echo "Found project revisions/tags:"
rm -f project_tags.txt
for project_revision in ${project_revisions}; do
    echo $project_revision >> project_tags.txt
done
cat ./project_tags.txt
set -x

echo "Do the conversions"
for project_revision in ${project_revisions}; do
    repo_convert_rev_tag=${project_revision}
    convert_revision ${repo_convert_rev_tag}
done
