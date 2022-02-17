#!/bin/sh
#set -eo pipefail
set -e

rtt=$GIT_BRANCH_IMAGE_VERSION
rc=$(git rev-parse --short HEAD)
rb=$(git rev-parse --abbrev-ref HEAD)
currtag=$(git describe --tags --match "v[0-9]*" --abbrev=0 HEAD)
currbra=$rb
echo 000---$currtag
echo 111---$rtt
echo 222---$rc
echo 333---$rb



#1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p

#2.切换分支
if [ "$1" == 'Debug' ]; then
    git checkout $rb --
else
    git checkout $rtt
fi

#3.获取p2p版本号
VIDEOSDKRC=$(git rev-parse --short HEAD)
VIDEOSDKVERSION=$rb+git.$VIDEOSDKRC
if [ "$1" == 'Release' ]; then
    VIDEOSDKVERSION=$rtt+git.$VIDEOSDKRC
fi
VIDEOSDKVERSION=${VIDEOSDKVERSION#*v}
echo $VIDEOSDKVERSION

#4.编译enet库
mkdir -p build
cd build
sed -i "s/.*VIDEOSDKVERSION.*/static const char * VIDEOSDKVERSION = \"$VIDEOSDKVERSION\";/g" ../app_interface/app_p2p/appWrapper.h

cmake -DCOMPILE_SYSTEM=Windows -DCMAKE_BUILD_TYPE=Release -DENET_NO_STATIC_BINARY=ON -DBUNDLE_CERTS=OFF -DWITH_DHT=OFF -DBUILD_WITH_FS=OFF -DWITH_ZIP=OFF -DENABLE_TCP_PUNCH=ON -DENET_VERSION=lts_1.3 ..
cmake --build . --config Release

cd ../samples/windows_p2p/

#5.编译app_interface库
cp -r ../../app_interface/app_p2p      app_interface/app_p2p
cp -r ../../app_interface/cloud_api    app_interface/cloud_api
cp -r ../../app_interface/curl_inc     app_interface/curl
cp -r ../../app_interface/utils        app_interface/utils

mkdir build
cd build

cmake .. -DCOMPILE_SYSTEM=linux -DSYSTEM_ARCH=x86 -DCOMPILE_TYPE=Release
cmake --build . --config Release
ls -l ../p2p_sample/

poddatetime=$(date '+%Y%m%d%H%M')
echo $poddatetime
