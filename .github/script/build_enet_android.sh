#!/bin/sh

cmake --version

# gpg --quiet -d --passphrase "$PROVISIONING_PASSWORD" --batch .github/file/CMakeLists_android.txt.asc > .github/file/CMakeLists_android.txt
echo $GIT_BRANCH_IMAGE_VERSION

# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p
git checkout $GIT_BRANCH_IMAGE_VERSION

rc=$(git rev-parse --short HEAD)
echo $rc

cd components_src/eNet/samples/android



# 2.编译Linux平台工程配置
rm -rf xnet/jni/*
rm -rf xnet/src/main/java/com/tencent/xnet/*

# 拷贝源文件
cp ../../../../android/java/* xnet/src/main/java/com/tencent/xnet/
cp ../../../../android/cpp/* xnet/jni

# 拷贝构建脚本
cp ../../../../android/build.gradle xnet/
cp ../../../../android/CMakeLists.txt xnet/
cp ../../../../android/AndroidManifest.xml xnet/src/main/


# cp ../../../../../.github/file/CMakeLists_android.txt   xnet/CMakeLists.txt
cp ../../../../../.github/file/libcurl_android.a            ../../../../app_interface/libcurl.a

#mv ../../../../app_interface/iot_inc/exports/*     ../../../../app_interface
#mv ../../../../app_interface/iot_inc/*             ../../../../app_interface
mv ../../../../app_interface/curl_inc/*            ../../../../app_interface

mv ../../../../app_interface/*        xnet/jni

# 将需要暴露的.h文件移至assets目录，这样可以将.h文件打进aar
mkdir xnet/src/main/assets
cp xnet/jni/appWrapper.h xnet/src/main/assets

# 3.gradlew 编译

sudo apt-get update -y
sudo apt-get install -y ninja-build
ninja --version
