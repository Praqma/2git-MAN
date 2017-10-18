#!/usr/bin/env bash
set -e
set -x

# parameter $1 is the project list file generated by the baseline_history.sh script
export repo_name=${1}
export repo_init_tag=${2}
export repo_submodules=${3}
export gitrepo_project_original=${4}
export gitignore_file=${5} # FULL PATH

#export project_revisions=`cat ${1}`

export gitrepo_project_original=${gitrepo_project_original}
export gitrepo_project_submodule=${gitrepo_project_original}
export git_remote=git-unisource.md-man.biz:7999
export git_remote_repo=ssh://git@${git_remote}/${gitrepo_project_original}/${repo_name}.git

#initialize repo
if [ ! -e ${repo_name} ] ; then
    git clone --recursive ${git_remote_repo}
    cd ${repo_name}
    git checkout -B master ${repo_init_tag}
    git reset --hard ${repo_init_tag} >> /dev/null
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

    git reset --hard ${repo_name}/${repo_init_tag}/${repo_init_tag} >> /dev/null
    git clean -xffd
    pwd
    # we are still in the root repo
else
    echo "Already cloned and initialized"
    echo "Reset all tags to remote"
    grep "${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$" |  xargs git tag --delete
    git fetch --tags
    pwd
    cd ${repo_name}
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
                            | grep -v ${repo_name}/.*/.*_[dprtis][eueenq][lblsta]$ \
                            | grep -v ${repo_init_tag}$ \
                            | tac \
                           )
set -x
echo "${project_revisions}"
for project_revision in ${project_revisions}; do
    repo_convert_rev_tag=${project_revision}
    ccm_repo_convert_rev_tag=${repo_convert_rev_tag:: -4}

    ccm_baseline_obj_this=$(ccm query "has_project_in_baseline('${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:1') and release='$(ccm query "name='${repo_name}' and version='$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g')' and type='project'" -u -f "%release")'" -u -f "%objectname" | head -1 )
    ccm_component_release=`ccm attr -show release "${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:1" | sed -e 's/ //g'`
    ccm_release=$(echo ${ccm_component_release} | cut -d "/" -f 2)

    test "${ccm_release}x" == "x" && exit 1

    repo_convert_rev_tag_wcomponent_wstatus="${repo_name}/${ccm_release}/${repo_convert_rev_tag}"

    if [ `git describe ${repo_convert_rev_tag_wcomponent_wstatus}` ] ; then
      continue
    fi

    # Get the right content
    if [ `git describe ${repo_convert_rev_tag}`  ] ; then
        # we do have the correct 'content' tag checkout it out
        git reset --hard ${repo_convert_rev_tag} >> /dev/null
    else
        # we do not have the 'content' tag available - investigate its history if it exists ( e.g. missing in repo )
        ./ccm-baseline-history-get-root.sh "${repo_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g')"
        exit 1
    fi

    git clean -xffd >> /dev/null

    baseline_from_tag_info=$(git show ${repo_convert_rev_tag} | grep "1) ${repo_name}~" | awk -F"~" '{print $2}')
    if [ "${baseline_from_tag_info}X" != "X" ] ; then
        repo_baseline_rev_tag_wcomponent_wstatus=$(git tag | grep "${repo_name}/.*/${baseline_from_tag_info}_[dprtis][eueenq][lblsta]$" || grep_ext_value=$? )
        if [ "${repo_baseline_rev_tag_wcomponent_wstatus}x" == "x" ] ; then
            exit 1
        fi
    else
        repo_baseline_rev_tag_wcomponent_wstatus="${repo_name}/${repo_init_tag}/${repo_init_tag}"
    fi

    # Move the workarea pointer to the 'baseline' tag
    git reset --mixed ${repo_baseline_rev_tag_wcomponent_wstatus} >> /dev/null
    git checkout HEAD .gitignore

    for repo_submodule in ${repo_submodules}; do
        repo_submodule_rev=$(ccm query " \
                                   hierarchy_project_members(\
                                       '${ccm_project_name}~$(echo ${ccm_repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:1',none \
                                   ) \
                                   and name='${repo_submodule}'" -u -f "%version" | sed -s 's/ /xxx/g')
        if [ "${repo_submodule_rev}X" == "X" ] ; then
            echo "The submodule does not exit as a project - skip"
            continue
        fi
        git checkout HEAD .gitmodules || echo ".gitmodules does not exist in current revision"
        if [ ! `git checkout HEAD ${repo_submodule}` ] ; then
                git rm -rf ${repo_submodule} || rm -rf ${repo_submodule}
                git submodule add --force ssh://git@${git_remote}/${gitrepo_project_submodule}/${repo_submodule}.git
        fi
        git submodule update --init --recursive


        cd ${repo_submodule}

        git fetch --tags

        if [ `git describe ${repo_convert_rev_tag_wcomponent_wstatus}` ] ; then
            # we already have the correct tag, so just set it and move on..
            git checkout ${repo_convert_rev_tag_wcomponent_wstatus}
            git clean -xffd
            repo_submodule_rev=""
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
        cd -

    done
    git add -A . >> /dev/null

    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${repo_convert_rev_tag} | awk -F" " '{print $1 " " $2}')
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}

    git commit -C ${repo_convert_rev_tag} --reset-author >> /dev/null || ( echo "Empty commit.." )

    git tag -l --format '%(contents)' ${repo_convert_rev_tag} > ./tag_meta_data.txt
    git tag -a -F ./tag_meta_data.txt ${repo_convert_rev_tag_wcomponent_wstatus}
    rm -f ./tag_meta_data.txt

    unset GIT_AUTHOR_DATE
    unset GIT_COMMITTER_DATE
    unset repo_convert_rev_tag_wcomponent_wstatus
    unset repo_baseline_rev_tag_wcomponent_wstatus


#    git push origin -f --tag ${repo_convert_rev_tag_wcomponent_wstatus}
set +x
    echo "============================================================================"
    echo " NEXT "
    echo "============================================================================"
set -x
done

