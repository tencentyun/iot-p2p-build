#!/bin/sh
#set -eo pipefail

cd iot-p2p

echo "first cmake"
cmake --version
ls -l

wget https://cmake.org/files/v3.16/cmake-3.16.0-Linux-x86_64.tar.gz
tar zxvf cmake-3.16.0-Linux-x86_64.tar.gz

#当前用户临时生效
export PATH=$PATH:./cmake-3.16.0-Linux-x86_64/bin
echo "second cmake"
cmake --version


wget https://dl.google.com/android/repository/android-ndk-r16b-linux-x86_64.zip
unzip android-ndk-r16b-linux-x86_64.zip


mkdir -p build/android_arm64
cd build/android_arm64
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=./android-ndk-r16b/build/cmake/android.toolchain.cmake  -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9  -DANDROID_NDK=./android-ndk-r16b  -DCMAKE_BUILD_TYPE=Release  -DANDROID_NATIVE_API_LEVEL=android-9  -DANDROID_ABI=arm64-v8a -DANDROID_TOOLCHAIN=clang
make all -j8

cd ../../
mkdir -p build/android_armv7
cd build/android_armv7
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=./android-ndk-r16b/build/cmake/android.toolchain.cmake  -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9  -DANDROID_NDK=./android-ndk-r16b  -DCMAKE_BUILD_TYPE=Release  -DANDROID_NATIVE_API_LEVEL=android-9  -DANDROID_ABI=armeabi-v7a -DANDROID_TOOLCHAIN=clang
make all -j8
