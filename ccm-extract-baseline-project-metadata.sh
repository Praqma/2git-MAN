#!/usr/bin/env bash
set -e

[[ "$debug" == "true" ]] && set -x
#set -u


ccm_project_name=$1
repo_convert_rev_tag=$2
repo_convert_instance=$3
require_baseline_object="false"

[[ -z $4 ]] && ( echo "Please set parameter 4 to Jira Project Key - exit 1" && exit 1 )
jira_project_key=$4

[[ -z $5 ]] && ( echo "Please set parameter 5 to 'commit' or 'tag' - exit 1" && exit 1 )
target_type=$5

jira_task_to_jira_issue_base=9000000

if [[ $target_type == "tag" ]] ; then
    extract_data_epic_level="true"
    extract_data_story_level="false"
    extract_data_ccm_task_level="false"
    extract_data_ccm_task_handle_dirtytasks_separately="false"
    extract_data_ccm_task_verbosed_level="false"
elif [[ $target_type == "commit" ]] ; then
    extract_data_epic_level="true"
    extract_data_story_level="true"
    extract_data_ccm_task_level="true"
    extract_data_ccm_task_handle_dirtytasks_separately="false"
    extract_data_ccm_task_verbosed_level="true"
else
    echo "Parameter 5 is not set to 'commit' or 'tag' - exit 1" && exit 1
fi

ccm_current_db=`ccm status -f "%database %current_session" | grep TRUE | awk -F " " '{print $1}'`
case ${ccm_current_db} in
    /data/ccmdb/db_functionDevelopment|/data/ccmdb/db_automation|/data/ccmdb/db_module|/data/ccmdb/db_application)
        epic_level_header="Change Requests: (CR)"
        epic_level_release_attr="TargetRelease"
        epic_level_epic2story_relation="associatedWP"

        story_level_header="Work Packages (WP)"
        story_level_release_attr="TargetRelease"
        require_baseline_object="true"
        ;;
    /data/ccmdb/ME_ECS)
        epic_level_header="Master Change Requests: (MCR)"
        epic_level_release_attr="release"
        epic_level_epic2story_relation="associatedImpl"

        story_level_header="Implementation Change Requests(ICR)"
        story_level_release_attr="release"
        ;;
    *)
        echo "Undetermined/supported: ccm_current_db: ${ccm_current_db}"
        exit 1
esac

test "${ccm_project_name}x" == "x"      && ( echo "'ccm_project_name' not set - exit"       && exit 1 )
test "${repo_convert_rev_tag}x" == "x"  && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )
test "${repo_convert_instance}x" == "x"  && ( echo "'repo_convert_rev_tag' not set - exit"   && exit 1 )

output_file="./meta_data.txt"
rm -f ${output_file}

function handle_task_attrs {
    local _task_number_attrs=$1
    if [[ ${_task_number_attrs} == "none" ]] ; then
        echo "<none>">> ${output_file}
    else
        #         1      2      3      4      5      6
        regex='^(.+)@@@(.+)@@@(.+)@@@(.+)@@@(.+)@@@(.+)$'
        [[ ${_task_number_attrs} =~ $regex ]] || exit 1
        task_objectname=${BASH_REMATCH[1]}
        task_number=${BASH_REMATCH[2]}
        task_create_time=${BASH_REMATCH[3]}
        task_resolver=${BASH_REMATCH[4]}
        task_status=${BASH_REMATCH[5]}
        task_release="${BASH_REMATCH[6]}"
        task_synopsis=$(ccm attr -show task_synopsis ${task_objectname})
        jira_subtask_issue_number=$(($jira_task_to_jira_issue_base + $task_number))
        printf "%-5s %-15s %-10s %-6s %-9s %-30s %s\n" " $loop_number)" "${jira_project_key}-${jira_subtask_issue_number}" "$task_create_time" "$task_resolver" "$task_status" "$task_release" "$task_synopsis" >> ${output_file}
    fi
}

ccm_baseline_obj_this=$(ccm query "has_project_in_baseline('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}') and release='$(ccm query "name='${ccm_project_name}' and version='$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g')' and type='project'" -u -f "%release")'" -u -f "%objectname" | head -1 )
if [ "${ccm_baseline_obj_this}X" != "X" ]; then
    ccm baseline -show info -v "${ccm_baseline_obj_this}"            >> ${output_file}
    echo >> ${output_file}

    printf "Project baseline:"                                         >> ${output_file}
    ccm query "is_baseline_project_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}')" -u -f "%displayname" >> ${output_file} || echo "  <none>" >> ${output_file}

    if [[ $extract_data_epic_level == "true" ]]; then
        echo >> ${output_file}
        echo "${epic_level_header}:"                                    >> ${output_file}
        ccm query "has_${epic_level_epic2story_relation}(has_associated_task((is_task_in_baseline_of('${ccm_baseline_obj_this}') or is_dirty_task_in_baseline_of('${ccm_baseline_obj_this}'))))" -f "${jira_project_key}-%problem_number %resolver %${epic_level_release_attr} %problem_synopsis" >> ${output_file} || echo "<none>" >> ${output_file}
    fi

    if [[ $extract_data_story_level == "true" ]]; then
        echo >> ${output_file}
        echo "Fully integrated ${story_level_header}:"                   >> ${output_file}
        ccm baseline -show fully_included_change_requests -groupby "${epic_level_release_attr}: %${epic_level_release_attr}"  -f "${jira_project_key}-%problem_number %resolver %${epic_level_release_attr} %problem_synopsis" "${ccm_baseline_obj_this}" >> ${output_file}  || echo "<none>" >> ${output_file}

        echo >> ${output_file}
        echo "Partially integrated ${story_level_header}:"               >> ${output_file}
        ccm baseline -show partially_included_change_requests -groupby "${epic_level_release_attr}: %${epic_level_release_attr}" -f "${jira_project_key}-%problem_number %resolver %${epic_level_release_attr} %problem_synopsis" "${ccm_baseline_obj_this}" >> ${output_file}  || echo "<none>" >> ${output_file}
    fi

    if [[ $extract_data_ccm_task_level == "true" ]]; then
        echo >> ${output_file}
        if [[ ${extract_data_ccm_task_handle_dirtytasks_separately} == "true" ]]; then
            echo "Tasks integrated in baseline:"                             >> ${output_file}
            query1="is_task_in_baseline_of('${ccm_baseline_obj_this}')"
            query2="is_dirtytask_in_baseline_of('${ccm_baseline_obj_this}')"
        else
            echo "All tasks integrated in baseline:"                             >> ${output_file}
            query1="is_task_in_baseline_of('${ccm_baseline_obj_this}') or is_dirty_task_in_baseline_of('${ccm_baseline_obj_this}')"
        fi

        IFS=$'\n\r'
        loop_number=1
        for task_number_attrs in $(ccm query "${query1}" -u -f "%objectname@@@%task_number@@@%{create_time[dateformat='yyyy-MM-dd HH:MM:SS']}@@@%resolver@@@%status@@@%release" || ( [[ $? == 6 ]] && echo "none" ) ) ; do
            handle_task_attrs "$task_number_attrs"
            loop_number=$((loop_number + 1))
        done
        unset IFS

        if [[ ${extract_data_ccm_task_handle_dirtytasks_separately} == "true" ]]; then
            echo >> ${output_file}
            echo "Dirty tasks integrated in baseline: ( listed in baseline, but has not effect as it's objects are behind the baseline project )"                             >> ${output_file}
            IFS=$'\n\r'
            loop_number=1
            for task_number_attrs in $(ccm query "${query2}')" -u -f "%objectname@@@%task_number@@@%{create_time[dateformat='yyyy-MM-dd HH:MM:SS']}@@@%resolver@@@%status@@@%release" || ( [[ $? == 6 ]] && echo "none" ) ) ; do
                handle_task_attrs "$task_number_attrs"
                loop_number=$((loop_number + 1))
            done
            unset IFS
        fi
    fi

    if [[ $extract_data_ccm_task_verbosed_level == "true" ]]; then
        echo >> ${output_file}
        echo "Tasks integrated in baseline and/or project (verbosed):"                   >> ${output_file}
        integrated_tasks=$(ccm query "is_task_in_baseline_of('${ccm_baseline_obj_this}')" || ( [[ $? == 6 ]] && echo "none" ))
        if [[ ${integrated_tasks} == "none" ]]; then
            echo "<none>"           >> ${output_file}
        else
            ccm task -sh info -v @  >> ${output_file}
        fi
        echo >> ${output_file}
    fi

else
    [[ "${require_baseline_object}" == "true" ]] && ( echo "ERROR: It is expected to have a baseline object due to configuration: require_baseline_object=true for this database: ${ccm_current_db}" && exit 2 )
    echo > ${output_file}
    echo "NO BASELINE OBJECT ASSOCIATED WITH THIS PROJECT VERSION"  >> ${output_file}
    echo >> ${output_file}

    echo "Project baseline:"                                         >> ${output_file}
    ccm query "is_baseline_project_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}')" -f "%displayname"  >> ${output_file} || echo "  <none>" >> ${output_file}
    echo >> ${output_file}

    echo "${epic_level_header}:"                                     >> ${output_file}
    ccm query "has_${epic_level_epic2story_relation}(has_associated_task(is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}'))))" -f "${jira_project_key}-%problem_number %resolver %release %problem_synopsis" >> ${output_file}  || echo "<none>" >> ${output_file}

    echo >> ${output_file}

    echo "Related/Integrated ${story_level_header}:"   >> ${output_file}
    ccm query "has_associated_task(is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}')))" -f "${jira_project_key}-%problem_number%resolver %release %problem_synopsis"  >> ${output_file}  || echo "<none>" >> ${output_file}

    echo >> ${output_file}
    echo "Tasks integrated in project:"                              >> ${output_file}
    ccm query "is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}'))" -f "%displayname %{create_time[dateformat='yyyy-M-dd HH:MM:SS']} %resolver %status %release %task_synopsis"  >> ${output_file} || echo "<none>" >> ${output_file}
    IFS=$'\n\r'
    loop_number=1
    for task_number_attrs in $(ccm query "is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}'))" -u -f "%objectname@@@%task_number@@@%{create_time[dateformat='yyyy-MM-dd HH:MM:SS']}@@@%resolver@@@%status@@@%release" | tail -n +2) ; do
        #         1      2      3      4      5      6
        regex='^(.+)@@@(.+)@@@(.+)@@@(.+)@@@(.+)@@@(.+)$'
        [[ $task_number_attrs =~ $regex ]] || exit 1
        task_objectname=${BASH_REMATCH[1]}
        task_number=${BASH_REMATCH[2]}
        task_create_time=${BASH_REMATCH[3]}
        task_resolver=${BASH_REMATCH[4]}
        task_status=${BASH_REMATCH[5]}
        task_release=${BASH_REMATCH[6]}
        task_synopsis=$(ccm attr -show task_synopsis ${task_objectname})
        jira_subtask_issue_number=$(($jira_task_to_jira_issue_base + $task_number))
        printf "$loop_number) ${jira_project_key}-${jira_subtask_issue_number} $task_create_time $task_resolver $task_status $task_release %s\n" $task_synopsis >> ${output_file}
        loop_number=$((loop_number + 1))
    done
    unset IFS

    if [[ $extract_data_ccm_task_verbosed_level == "true" ]]; then
        echo >> ${output_file}
        echo "Tasks integrated in baseline and/or project (verbosed):"                   >> ${output_file}
        integrated_tasks=$(ccm query "is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}'))" || ( [[ $? == 6 ]] && echo "none" ))
        if [[ ${integrated_tasks} == "none" ]]; then
            echo "<none>"           >> ${output_file}
        else
            ccm task -sh info -v @  >> ${output_file}
        fi
        echo >> ${output_file}
    fi

fi
if [[ "$debug" == "true" ]]; then
    echo "debug mode - do not verbose output_file and delete it"
else
    cat ${output_file}
    rm -f ${output_file}
fi