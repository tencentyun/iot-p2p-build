#!/bin/sh

rc=$(git rev-parse --short HEAD)
echo $rc

gpg --quiet -d --passphrase "$PROVISIONING_PASSWORD" --batch .github/file/CMakeLists.txt.asc > .github/file/CMakeLists.txt

git branch
echo $GIT_BRANCH_IMAGE_VERSION

CURVERSION=$(git describe --tags `git rev-list --tags --max-count=1`)
echo $CURVERSION
# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p

git checkout $GIT_BRANCH_IMAGE_VERSION


#git config --global user.name "codefarmer"
#git config --global user.name "dev_tester@163.com"

#git config --list

#datetime=$(date '+%Y-%m-%d %H:%M:%S')
#echo $datetime >> readme.md
#
#echo $datetime

#git add .
#git commit -m "tencentyun/iot-p2p@$rc"
#echo ":wq" | git commit --amend --author='codefarmer <dev_tester@163.com>'

#echo "whhhhhhstart"
#git log -2
#echo "whhhhhhstend"


#if [ $1 == 'Release' ]; then
#    echo "Release"
#    # 更新版本，确定对应关系
#    git tag $CURVERSION
#    git push https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git --tags
#else
#    echo "Debug"
#fi

cd components_src/eNet


# 2.编译iOS平台工程配置
mkdir -p build/ios

cd build/ios

cp ../../../../../.github/file/CMakeLists.txt   ../../CMakeLists.txt
cp ../../../../../.github/file/libcurl.a        ../../../../app_interface/libcurl.a

mv ../../../../app_interface/iot_inc/exports/*     ../../../../app_interface
mv ../../../../app_interface/iot_inc/*     ../../../../app_interface
mv ../../../../app_interface/curl_inc/*     ../../../../app_interface

mv ../../../../app_interface/   ../../../../components_src/eNet/src/app_interface/

cmake ../.. -GXcode -DCMAKE_INSTALL_PREFIX=$PWD/INSTALL -DENET_SELF_SIGN=ON -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_BUILD_TYPE=Debug -DENET_VERSION=v1.0.0 -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python3


# build lib
#rm -rf build
xcodebuild build -project eNet.xcodeproj -scheme enet_static -configuration Release -sdk iphoneos -derivedDataPath ./build
#xcodebuild build -project eNet.xcodeproj -scheme enet_static -configuration Release -sdk iphonesimulator -derivedDataPath ./build

#strip -x -S Release-iphoneos/libenet.a -o  Release-iphoneos/libenet_.a
#lipo -info Release-iphoneos/libenet.a






#触发pod发布
git clone https://$GIT_ACCESS_TOKEN@github.com/tonychanchen/TIoTThridSDK.git
cd TIoTThridSDK

cp ../Release-iphoneos/libenet.a  TIoTThridSDK/XP2P-iOS/libenet.a

poddatetime=$(date '+%Y%m%d%H%M')
echo $poddatetime

git add .
git commit -m "tencentyun/iot-p2p-build@$rc"
git push https://$GIT_ACCESS_TOKEN@github.com/tonychanchen/TIoTThridSDK.git

git tag "1.0.0-beta.$poddatetime"
git push https://$GIT_ACCESS_TOKEN@github.com/tonychanchen/TIoTThridSDK.git --tags
