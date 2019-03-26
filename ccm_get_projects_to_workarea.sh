

export PATH=/cygdrive/c/Program\ Files\ \(x86\)/Git/bin:${PATH}
export PATH=/cygdrive/c/Cygwin/bin:${PATH}

export PATH=/c/Program\ Files\ \(x86\)/Git/bin:${PATH}

export PATH=/c/Program\ Files/Git/usr/bin/:${PATH}
export PATH=/c/Program\ Files/Git/bin/:${PATH}
export PATH=/c/Program\ Files/Git/mingw64/bin/:${PATH}
export PATH=/c/Program\ Files\ \(x86\)/ibm/rational/synergy/7.2.1/bin:${PATH}

export PATH=/c/Cygwin/bin:${PATH}

create_wa=$1
if [ "${2}X" != "X" ]; then
 debug=$2
fi

#SAVEIFS=$IFS
#IFS=$(echo -en "\n")

GetCCMProjectList() {
	ccm query "name='me' \
				and (status='released' or status='integrate' or status='sqa' or status='test') \
				and (version match 'ME-ECS-SW-????-?.?' or version match 'ME-ECS-SW-?????-?.?' ) \
				and not (version match '* *') \
				" -f "%objectname" -u | sed -e 's/ /xxx/g' > projects.txt
	dos2unix projects.txt
	for line in `cat projects.txt`; do
		projects="$line $projects"
	done
}

if [ "${debug}X" == "trueX" ] ; then
  echo ${PATH}
  pwd
  set -x
fi

GetCCMProjectList
no_proj=`echo $projects | wc -w`
echo "Number of projects to convert to workarea: $no_proj"
rm -f baselines.txt && touch baselines.txt
rm -f projects_info.txt && touch projects_info.txt
rm -f baselines_sort_unique.txt

echo "Finding baselines for projects:"
for project in ${projects} ; do
	printf "."
	project=`printf ${project}| sed -e 's/xxx/ /g'`
	query="is_baseline_project_of('${project}') "
	ccm_baseline=`ccm query "$query" -u -f "%objectname" | sed -e 's/ /xxx/g'` 
	echo "$ccm_baseline" >> baselines.txt
    if [ "${ccm_baseline}X" == "X" ] ; then
	  ccm_baseline="void"
	fi
	ccm_status=$(ccm attr -show status $project)
	echo $project $ccm_baseline $ccm_status >> projects_info.txt
done
echo
cat baselines.txt | sort -u > baselines_sort_unique.txt
no_baselines=`cat baselines_sort_unique.txt | wc -w `
echo "Adding baselines to checkout list as well: ${no_baselines}"
cat projects.txt baselines_sort_unique.txt | sort -u > ccm_project_total.txt
no_total=`cat ccm_project_total.txt | wc -w `
echo "Total: ${no_total}"

for project in `cat ccm_project_total.txt` ; do
	name_version=`echo "${project}" | awk -F':' '{print $1}'`
	project=`printf ${project}| sed -e 's/xxx/ /g'`
	printf "Copy to disk: ${project} : "
	if [ -d ${name_version}_tmp ]; then
		printf " remove tmp"
		rm -rf ${name_version}_tmp
		printf " : "
	fi
	if [ -d ${name_version} ]; then
		printf " already exists\n"
	else
		if [ "${create_wa}X" == "trueX" ]; then
			printf " copy: "
			ccm copy_to_file_system -p ${name_version}_tmp -r "${project}" > /dev/null
			mv ${name_version}_tmp ${name_version} || ( printf " sleep 5" && sleep 5 && mv ${name_version}_tmp ${name_version} )
		fi
		printf "Done\n"
	fi
done

#IFS=$SAVEIFS

