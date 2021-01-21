#!/bin/sh

cmake --version

gpg --quiet -d --passphrase "$PROVISIONING_PASSWORD" --batch .github/file/CMakeLists_android.txt.asc > .github/file/CMakeLists_android.txt


# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p

rc=$(git rev-parse --short HEAD)
echo $rc

cd components_src/eNet/samples/android



# 2.编译Linux平台工程配置
rm -rf xnet/jni/*
cp ../../../../../.github/file/CMakeLists_android.txt   xnet/CMakeLists.txt
cp ../../../../../.github/file/libcurl_android.a            ../../../../app_interface/libcurl.a

mv ../../../../app_interface/iot_inc/exports/*     ../../../../app_interface
mv ../../../../app_interface/iot_inc/*             ../../../../app_interface
mv ../../../../app_interface/curl_inc/*            ../../../../app_interface

mv ../../../../app_interface/*        xnet/jni

# 3.gradlew 编译

sudo apt-get update -y
sudo apt-get install -y ninja-build
ninja --version