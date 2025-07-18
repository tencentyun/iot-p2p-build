#!/bin/sh
#set -eo pipefail
# 安装必要的构建工具
sudo apt-get update
sudo apt-get install -y ninja-build cmake

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

echo "/usr/local/lib/android/sdk/ndk/25.1.8937393"
ls -l /usr/local/lib/android/sdk/ndk/25.1.8937393/build/cmake

pwd ${ANDROID_HOME}

mkdir -p build/android_arm64
cd build/android_arm64
cmake ../.. \
  -DCMAKE_TOOLCHAIN_FILE=/usr/local/lib/android/sdk/ndk/25.1.8937393/build/cmake/android.toolchain.cmake \
  -DANDROID_NDK=/usr/local/lib/android/sdk/ndk/25.1.8937393 \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DANDROID_STL=c++_shared \
  -G Ninja
ninja -j8

cd ../../
mkdir -p build/android_armv7
cd build/android_armv7
cmake ../.. \
  -DCMAKE_TOOLCHAIN_FILE=/usr/local/lib/android/sdk/ndk/25.1.8937393/build/cmake/android.toolchain.cmake \
  -DANDROID_NDK=/usr/local/lib/android/sdk/ndk/25.1.8937393 \
  -DANDROID_ABI=armeabi-v7a \
  -DANDROID_PLATFORM=android-21 \
  -DANDROID_STL=c++_shared \
  -G Ninja
ninja -j8

cd ../../
mv build/android_arm64/libenet.a  android_device/lib/arm64-v8a
mv build/android_arm64/_deps/libevent-build/*.a  android_device/lib/arm64-v8a
mv build/android_arm64/_deps/mbedtls-build/library/*.a  android_device/lib/arm64-v8a
mv build/android_arm64/_deps/minizip-build/*.a  android_device/lib/arm64-v8a
mv build/android_arm64/_deps/tinyxml2-build/*.a  android_device/lib/arm64-v8a

mv build/android_armv7/libenet.a  android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/libevent-build/*.a  android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/mbedtls-build/library/*.a  android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/minizip-build/*.a  android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/tinyxml2-build/*.a  android_device/lib/armeabi-v7a

cd android_device
./cmake_build.sh ANDROID

ls -l output/arm64-v8a/
ls -l output/armeabi-v7a/

mv output/armeabi-v7a/libiot_video_demo.so   device_video_aar/explorer-device-video-sdk/libs/armeabi-v7a
mv output/arm64-v8a/libiot_video_demo.so   device_video_aar/explorer-device-video-sdk/libs/arm64-v8a
