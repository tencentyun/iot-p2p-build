#!/bin/sh
#set -eo pipefail
set -e

rtt=$GIT_BRANCH_IMAGE_VERSION
rc=$(git rev-parse --short HEAD)
rb=$(git rev-parse --abbrev-ref HEAD)
currtag=$(git describe --tags `git rev-list --tags --max-count=1`)
currbra=$rb
echo 000---$currtag
echo 111---$rtt
echo 222---$rc
echo 333---$rb

gpg --quiet -d --passphrase "$PROVISIONING_PASSWORD" --batch .github/file/CMakeLists.txt.asc > .github/file/CMakeLists.txt

#CURVERSION=$(git describe --tags `git rev-list --tags --max-count=1`) #获取tag
#echo $CURVERSION
# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p

#2. 切换分支
if [ $1 == 'Debug' ]; then
    git checkout $rb --
else
    git checkout $rtt
fi

#3. 获取pp版本号
VIDEOSDKRC=$(git rev-parse --short HEAD)
VIDEOSDKVERSION=$rb+git.$VIDEOSDKRC
if [ $1 == 'Release' ]; then
    VIDEOSDKVERSION=$rtt+git.$VIDEOSDKRC
fi
echo $VIDEOSDKVERSION


# 2.编译iOS平台工程配置
mkdir -p build/ios

cd build/ios

cp ../../../.github/file/CMakeLists.txt   ../../CMakeLists.txt
cp ../../../.github/file/libcurl.a        ../../app_interface/libcurl.a

mv ../../app_interface/curl_inc/*      ../../app_interface
mv ../../app_interface/app_p2p/*    ../../app_interface
mv ../../app_interface/cloud_api/*   ../../app_interface
mv ../../app_interface/utils/*           ../../app_interface

rm -rf ../../app_interface/utils
rm -rf ../../app_interface/cloud_api
rm -rf ../../app_interface/app_p2p
rm -rf ../../app_interface/curl_inc
rm -rf ../../app_interface/readme.md

mv ../../app_interface/   ../../src/app_interface/

cmake ../.. -GXcode -DCMAKE_INSTALL_PREFIX=$PWD/INSTALL -DENET_SELF_SIGN=ON -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_BUILD_TYPE=Debug -DENET_VERSION=v1.0.0 -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python3


# build lib
xcodebuild build -project eNet.xcodeproj -scheme enet_static -configuration Release -sdk iphoneos -derivedDataPath ./build

#strip -x -S Release-iphoneos/libenet.a -o  Release-iphoneos/libenet_.a
#lipo -info Release-iphoneos/libenet.a


# 检测C环境是否编译通过
echo "CCCCCCCCCCCCCCC"
mkdir -p ../../../.github/file/xp2p_c_demo/xp2p_c_demo/XP2P-iOS
cp ../../src/app_interface/appWrapper.h  ../../../.github/file/xp2p_c_demo/xp2p_c_demo/AppWrapper.h
cp Release-iphoneos/libenet.a  ../../../.github/file/xp2p_c_demo/xp2p_c_demo/XP2P-iOS/libenet.a
cp _deps/libevent-build/Release-iphoneos/libevent_*.a   ../../../.github/file/xp2p_c_demo/xp2p_c_demo/XP2P-iOS/
cp _deps/mbedtls-build/library/Release-iphoneos/libmbed*.a   ../../../.github/file/xp2p_c_demo/xp2p_c_demo/XP2P-iOS/
cp _deps/minizip-build/Release-iphoneos/libminizip.a   ../../../.github/file/xp2p_c_demo/xp2p_c_demo/XP2P-iOS/
cp ../../../.github/file/libcurl.a  ../../../.github/file/xp2p_c_demo/xp2p_c_demo/XP2P-iOS/

xcodebuild build -project ../../../.github/file/xp2p_c_demo/xp2p_c_demo.xcodeproj -scheme xp2p_c_demo -configuration Release -sdk iphoneos -derivedDataPath ./build



#触发pod发布
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-thirdparty-ios.git
cd iot-thirdparty-ios

cp ../../../src/app_interface/appWrapper.h  Source/XP2P-iOS/Classes/AppWrapper.h
sed -i "" "s/.*VIDEOSDKVERSION.*/static const char * VIDEOSDKVERSION = \"$VIDEOSDKVERSION\";/g" Source/XP2P-iOS/Classes/AppWrapper.h

cp ../Release-iphoneos/libenet.a Source/XP2P-iOS/libenet.a

poddatetime=$(date '+%Y%m%d%H%M')
echo $poddatetime

git add .
git commit -m "tencentyun/iot-p2p-build@$rc"
git push https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-thirdparty-ios.git

# ==========此处添加版本自增逻辑，如果是持续集成发snapshot，最新tag+1；如果是发布就发branch
vtag=${currtag#*v}
echo $vtag


branch=${currbra#*v}
vbranch=${branch%x*}0
echo $vbranch

function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

resultvv=$vbranch
if version_ge $vtag $vbranch; then
    
    echo "$vtag is greater than or equal to $vbranch"
    
    vtaglist=(${vtag//./ })
    
    firsttag=${vtaglist[0]}
    secondtag=${vtaglist[1]}
    thirdtag=${vtaglist[2]}
    thirdtag=`expr $thirdtag + 1`
    
    resultvv=$firsttag.$secondtag.$thirdtag
fi

echo "-->>$resultvv"

if [ $1 == 'Debug' ]; then
    git tag "$resultvv-beta.$poddatetime"
else
    git tag "$vtag"
fi
# ==========此处添加版本自增逻辑，如果是持续集成发snapshot，最新tag+1；如果是发布就发branch

git push https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-thirdparty-ios.git --tags
