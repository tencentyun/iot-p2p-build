#!/bin/sh

gpg --quiet -d --passphrase "$PROVISIONING_PASSWORD" --batch .github/file/CMakeLists.txt.asc > .github/file/CMakeLists.txt

# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git

cd iot-p2p/components_src/eNet



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
