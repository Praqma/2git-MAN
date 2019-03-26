#!/bin/bash
#set -x

rm -rf mercury_dev_orig
git clone ssh://git@git-unisource.md-man.biz:7999/tardis/mercury_dev_orig.git
cd mercury_dev_orig
git checkout -B 1703/master PMI-1703-BASETEST_20171017_pub
git push --set-upstream origin 1703/master

git checkout -B master PMI-DEV-BASETEST_20171003_pub
git push origin -f
cd -

rm -rf tardis_dev_orig
git clone ssh://git@git-unisource.md-man.biz:7999/tardis/tardis_dev_orig.git
cd tardis_dev_orig
cd git checkout -B master TARDIS_DEV_BASETEST_20171005_pub
git push origin -f

git checkout -B 1703/master basetest_tardis_1703_20171008_pub
git push --set-upstream origin 1703/master
cd -

rm -rf mercury_dev
git clone ssh://git@git-unisource.md-man.biz:7999/tardis/mercury_dev.git
cd mercury_dev
git checkout -B master mercury_dev/dev1704/PMI-DEV-BASETEST_20171003_pub
git submodule update --init --recursive
git push origin -f

git checkout -B 1703/master mercury_dev/1703-2/PMI-1703-BASETEST_20171017_pub
git submodule update --init --recursive
git push --set-upstream origin 1703/master
cd -

rm -rf tardis_dev
git clone ssh://git@git-unisource.md-man.biz:7999/tardis/tardis_dev.git
cd tardis_dev
git checkout -B master tardis_dev/dev1704/TARDIS_DEV_BASETEST_20171005_pub
git submodule update --init --recursive
git push origin -f

git checkout -B 1703/master tardis_dev/1703-5/basetest_tardis_1703_20171008_pub
git submodule update --init --recursive
git push --set-upstream origin 1703/master
cd -