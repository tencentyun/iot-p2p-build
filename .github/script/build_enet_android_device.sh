#!/bin/sh
#set -eo pipefail

set -e
cmake --version

rb=$(git rev-parse --abbrev-ref HEAD)
echo $rb
echo $GIT_BRANCH_IMAGE_VERSION

# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p
if [ "$1" = "Release" ]; then
    git checkout $GIT_BRANCH_IMAGE_VERSION
else
    git checkout $rb
fi


#echo "first cmake"
#cmake --version
#ls -l
#
#wget https://cmake.org/files/v3.16/cmake-3.16.0-Linux-x86_64.tar.gz
#tar zxvf cmake-3.16.0-Linux-x86_64.tar.gz
#
##当前用户临时生效
#export PATH=$PATH:./cmake-3.16.0-Linux-x86_64/bin
echo "second cmake"
cmake --version


#wget https://dl.google.com/android/repository/android-ndk-r16b-linux-x86_64.zip
#unzip android-ndk-r16b-linux-x86_64.zip
which ndk

mkdir -p build/android_arm64
cd build/android_arm64
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=./android-ndk-r16b/build/cmake/android.toolchain.cmake  -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9  -DANDROID_NDK=./android-ndk-r16b  -DCMAKE_BUILD_TYPE=Release  -DANDROID_NATIVE_API_LEVEL=android-9  -DANDROID_ABI=arm64-v8a -DANDROID_TOOLCHAIN=clang
make all -j8

cd ../../
mkdir -p build/android_armv7
cd build/android_armv7
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=./android-ndk-r16b/build/cmake/android.toolchain.cmake  -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9  -DANDROID_NDK=./android-ndk-r16b  -DCMAKE_BUILD_TYPE=Release  -DANDROID_NATIVE_API_LEVEL=android-9  -DANDROID_ABI=armeabi-v7a -DANDROID_TOOLCHAIN=clang
make all -j8
