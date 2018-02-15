#!/usr/bin/env bash

ccm query "\
hierarchy_project_members('me-b~ME-B-SW-1403-4.16:project:1',none) or \
hierarchy_project_members('ercs~pqs-ercs-1803:project:1',none) or \
hierarchy_project_members('me~ME_1712_1_BaseTest_bm8:project:1',none) or \
hierarchy_project_members('me~ME-ECS-SW-1312-7.1:project:1',none) or \
\
hierarchy_project_members('HMI_devel~BES-HMI-SW-1709-1.6:project:1',none) or \
hierarchy_project_members('makedev2~makedev2-1709-1.4:project:1',none) or \
hierarchy_project_members('appfrdev~appframe-1705-1.5:project:1',none) \
hierarchy_project_members('arceditDev~Arcedit-1511-1.1:project:1',none) or \
hierarchy_project_members('modbusDev~Modbus-1511-3.2:project:1',none) or \
hierarchy_project_members('ldcl-dev~LDCL-1307-11.1:project:1',none) or \
hierarchy_project_members('scu-sw-dev~SCU-SW-1705-3.2:project:1',none) or \
hierarchy_project_members('PMI-ON-SW~1512-1.3:project:1',none) or \
hierarchy_project_members('aetherdev~1308-2.0:project:1',none) or \
hierarchy_project_members('DSE_Sim~DSE-1705-2.1:project:1',none) or \
hierarchy_project_members('tpu_dev~tpudev-0606_20070308:project:1',none) or \
hierarchy_project_members('hppc-dev~PVU-CS-SW-1801-1.3:project:1',none) or \
hierarchy_project_members('BES3_test~BES3_1210_BT_LDE5_LINUX_20180103:project:1',none) \
" -u -f "%name %instance" | /usr/bin/sort.exe -u | \
grep -v '^scr$' | \
grep -v '^egr$' | \
grep -v '^gi$' | \
grep -v '^dasu$' | \
grep -v '^dasu_prodtest$' | \
grep -v '^acu$' | \
grep -v '^axu$' | \
grep -v '^ccu_mrk2$' | \
grep -v '^ecu$' | \
grep -v '^eicu$' | \
grep -v '^esu$' | \
grep -v '^MOP2$' | \
grep  -v '^bootload_dist$' | \
grep -v '^pumpsim$' |  \
grep -v '^c$'

exit 0
# add the following grep section to list all subprojects _only_
| \
grep -v '^HMI_devel$' | \
grep -v '^makedev2$' | \
grep -v '^ercs$' | \
grep -v '^appfrdev$' | \
grep -v '^arceditDev$' | \
grep -v '^modbusDev$' | \
grep -v '^me$' | \
grep -v '^ldcl$' | \
grep -v '^scu-sw-dev$' | \
grep -v '^PMI-ON-SW$' | \
grep -v '^aetherdev$' | \
grep -v '^DSE_Sim$' | \
grep -v '^tpu_dev$' | \
grep -v '^hppc-dev$' | \
grep -v '^BES3_test$' | \
grep -v '^me-b$'

#.gitignore
#/bootload_dist/
#/pumpsim/