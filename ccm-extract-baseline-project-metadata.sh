#!/usr/bin/env bash
set -e

ccm_project_name=$1
repo_convert_rev_tag=$2
repo_convert_instance=$3

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

ccm_baseline_obj_this=$(ccm query "has_project_in_baseline('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}') and release='$(ccm query "name='${ccm_project_name}' and version='$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g')' and type='project'" -u -f "%release")'" -u -f "%objectname" | head -1 )
if [ "${ccm_baseline_obj_this}X" != "X" ]; then
    echo > ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Baseline information:"                                     >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm baseline -show info -v "${ccm_baseline_obj_this}"            >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Project baseline:"                                         >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm query "is_baseline_project_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}')" -f "%displayname" >> ./tag_meta_data.txt || echo "  <none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------">> ./tag_meta_data.txt
    echo "${epic_level_header}:"                                    >> ./tag_meta_data.txt
    echo "---------------------------------------------------------">> ./tag_meta_data.txt
    ccm query "has_${epic_level_epic2story_relation}(has_associated_task((is_task_in_baseline_of('${ccm_baseline_obj_this}') or is_dirty_task_in_baseline_of('${ccm_baseline_obj_this}'))))" -f "%displayname %resolver %${epic_level_release_attr} %problem_synopsis" >> ./tag_meta_data.txt || echo "<none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Fully integrated ${story_level_header}:"                   >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm baseline -show fully_included_change_requests -groupby "${epic_level_release_attr}: %${epic_level_release_attr}"  -f "%displayname %resolver %${epic_level_release_attr} %problem_synopsis" "${ccm_baseline_obj_this}" >> ./tag_meta_data.txt  || echo "<none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Partially integrated ${story_level_header}:"               >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm baseline -show partially_included_change_requests -groupby "${epic_level_release_attr}: %${epic_level_release_attr}" -f "%displayname %resolver %${epic_level_release_attr} %problem_synopsis" "${ccm_baseline_obj_this}" >> ./tag_meta_data.txt  || echo "<none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Tasks integrated in baseline:"                             >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm baseline -show tasks -f "%displayname %{create_time[dateformat='yyyy-MM-dd HH:MM:SS']} %resolver %status %release %task_synopsis" "${ccm_baseline_obj_this}" >> ./tag_meta_data.txt || echo "<none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Tasks integrated in baseline (verbosed):"                  >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm task -sh info -v @ >> ./tag_meta_data.txt || echo "<none>"   >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

else
    [[ "${require_baseline_object}" == "true" ]] && ( echo "ERROR: It is expected to have a baseline object due to configuration: require_baseline_object=true for this database: ${ccm_current_db}" && exit 2 )
    echo > ./tag_meta_data.txt
    echo "---------------------------------------------------------">> ./tag_meta_data.txt
    echo "NO BASELINE OBJECT ASSOCIATED WITH THIS PROJECT VERSION"  >> ./tag_meta_data.txt
    echo "---------------------------------------------------------">> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Project baseline:"                                         >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm query "is_baseline_project_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}')" -f "%displayname"  >> ./tag_meta_data.txt || echo "  <none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "${epic_level_header}:"                                     >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm query "has_${epic_level_epic2story_relation}(has_associated_task(is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}'))))" -f "%displayname %resolver %release %problem_synopsis" >> ./tag_meta_data.txt  || echo "<none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Related/Integrated ${story_level_header}:"   >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm query "has_associated_task(is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}')))" -f "%displayname %resolver %release %problem_synopsis"  >> ./tag_meta_data.txt  || echo "<none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Tasks integrated in project:"                              >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm query "is_task_in_folder_of(is_folder_in_rp_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:${repo_convert_instance}'))" -f "%displayname %{create_time[dateformat='yyyy-M-dd HH:MM:SS']} %resolver %status %release %task_synopsis"  >> ./tag_meta_data.txt || echo "<none>" >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt

    echo >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    echo "Tasks integrated in project (verbosed):"                   >> ./tag_meta_data.txt
    echo "---------------------------------------------------------" >> ./tag_meta_data.txt
    ccm task -sh info -v @ >> ./tag_meta_data.txt || echo "<none>"   >> ./tag_meta_data.txt
    echo >> ./tag_meta_data.txt
fi
cat ./tag_meta_data.txt
rm -f ./tag_meta_data.txt