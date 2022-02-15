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


#CURVERSION=$(git describe --tags `git rev-list --tags --max-count=1`) #获取tag
#echo $CURVERSION
# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p

#2. 切换分支
if [ "$1" == 'Debug' ]; then
    git checkout $rb --
else
    git checkout $rtt
fi

#3. 获取pp版本号
VIDEOSDKRC=$(git rev-parse --short HEAD)
VIDEOSDKVERSION=$rb+git.$VIDEOSDKRC
if [ "$1" == 'Release' ]; then
    VIDEOSDKVERSION=$rtt+git.$VIDEOSDKRC
fi
VIDEOSDKVERSION=${VIDEOSDKVERSION#*v}
echo $VIDEOSDKVERSION


# 2.编译iOS平台工程配置
mkdir -p build

cd build

#cp ../../../.github/file/CMakeLists.txt   ../../CMakeLists.txt
#perl -i -pe "s#.*armv7;armv7s;arm64.*#\t\tset(CMAKE_OSX_ARCHITECTURES \"arm64\" CACHE STRING \"\" FORCE)#g" ../../CMakeLists.txt
#perl -i -pe "s#.*src/proc.*#\t\"src/proc/*\"\n\t\"src/app_interface/*\"#g" ../../CMakeLists.txt
#perl -i -pe "s#.*bundle_static_library.*# #g" ../../CMakeLists.txt

sed -i "s/.*VIDEOSDKVERSION.*/static const char * VIDEOSDKVERSION = \"$VIDEOSDKVERSION\";/g" ../app_interface/app_p2p/appWrapper.h

#编译enet库
cmake -DCOMPILE_SYSTEM=Linux -DCMAKE_BUILD_TYPE=Release -DENET_NO_STATIC_BINARY=ON -DBUNDLE_CERTS=OFF -DWITH_DHT=OFF -DBUILD_WITH_FS=OFF -DWITH_ZIP=OFF -DENABLE_TCP_PUNCH=ON -DENET_VERSION=lts_1.3 ..
cmake --build . --config Release

cd ../samples/windows_p2p/

#编译app_interface库
cp -r ../../app_interface/app_p2p      app_interface/app_p2p
cp -r ../../app_interface/cloud_api    app_interface/cloud_api
cp -r ../../app_interface/curl_inc     app_interface/curl
cp -r ../../app_interface/utils        app_interface/utils

mkdir build
cd build

cmake .. -DCOMPILE_SYSTEM=linux -DSYSTEM_ARCH=x86 -DCOMPILE_TYPE=Release
cmake --build . --config Release
ls -l ../p2p_sample/
#libapp_interface.a

#mkdir xp2p_linux
#
#cp ../external_libs/lib/linux/x86/Release/libcurl.a          xp2p_linux/
#cp ../app_interface/app_p2p/appWrapper.h    xp2p_linux/AppWrapper.h
#cp app_interface/*.a                        xp2p_linux/
##cp ../../../build/libenet.a                 xp2p_linux/
#cp ../../../build/libenet-core.a            xp2p_linux/
#cp ../../../build/_deps/libevent-build/*.a  xp2p_linux/
#cp ../../../build/_deps/mbedtls-build/library/*.a       xp2p_linux/
#cp ../../../build/_deps/minizip-build/*.a               xp2p_linux/
#cp ../../../build/_deps/tinyxml2-build/*.a              xp2p_linux/
#cp ../../../build/_deps/zlib-build/*.a                  xp2p_linux/

poddatetime=$(date '+%Y%m%d%H%M')
echo $poddatetime
