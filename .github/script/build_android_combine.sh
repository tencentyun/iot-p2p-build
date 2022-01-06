#!/bin/sh

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

# 1.1获取p2p版本号
VIDEOSDKRC=$(git rev-parse --short HEAD)
rc=$rb+git.$VIDEOSDKRC
if [ "$1" = "Release" ]; then
    rc=$GIT_BRANCH_IMAGE_VERSION+git.$VIDEOSDKRC
fi
rc=${rc#*v}
echo $rc

# 2.拷贝app_interface源文件至android_device/samples/iot_video_demo
mkdir android_device/samples/iot_video_demo/app_interface
mv app_interface/curl_inc/*            android_device/samples/iot_video_demo/app_interface
mv app_interface/app_p2p/*             android_device/samples/iot_video_demo/app_interface
mv app_interface/cloud_api/*           android_device/samples/iot_video_demo/app_interface
mv app_interface/utils/*               android_device/samples/iot_video_demo/app_interface
rm android_device/samples/iot_video_demo/app_interface/utils_hmac.cpp

# 2.1 更新p2p代码版本
sed -i "s#.*VIDEOSDKVERSION.*#static const char * VIDEOSDKVERSION = \"$rc\";#g" android_device/samples/iot_video_demo/app_interface/appWrapper.h

mv ../.github/file/libs/arm64-v8a/libcurl.a    android_device/lib/arm64-v8a
mv ../.github/file/libs/armeabi-v7a/libcurl.a  android_device/lib/armeabi-v7a

# 3.编译iot_video_demo.so
mkdir -p build/android_arm64
cd build/android_arm64
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=/usr/local/lib/android/sdk/ndk/16.1.4479499/build/cmake/android.toolchain.cmake  -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9  -DANDROID_NDK=/usr/local/lib/android/sdk/ndk/16.1.4479499  -DCMAKE_BUILD_TYPE=Release  -DANDROID_NATIVE_API_LEVEL=android-9  -DANDROID_ABI=arm64-v8a -DANDROID_TOOLCHAIN=clang -DENET_NO_STATIC_BINARY=ON -DBUNDLE_CERTS=OFF -DWITH_DHT=OFF -DBUILD_WITH_FS=OFF -DWITH_ZIP=OFF -DWITH_XDFS=OFF -DWITH_UPNP=OFF
make all -j8

cd ../../
mkdir -p build/android_armv7
cd build/android_armv7
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=/usr/local/lib/android/sdk/ndk/16.1.4479499/build/cmake/android.toolchain.cmake  -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9  -DANDROID_NDK=/usr/local/lib/android/sdk/ndk/16.1.4479499  -DCMAKE_BUILD_TYPE=Release  -DANDROID_NATIVE_API_LEVEL=android-9  -DANDROID_ABI=armeabi-v7a -DANDROID_TOOLCHAIN=clang -DENET_NO_STATIC_BINARY=ON -DBUNDLE_CERTS=OFF -DWITH_DHT=OFF -DBUILD_WITH_FS=OFF -DWITH_ZIP=OFF -DWITH_XDFS=OFF -DWITH_UPNP=OFF
make all -j8

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

# 4.构建打包aar所需要的app头文件以及native-lib.cpp文件
mv ../android/java/*.java           device_video_aar/explorer-device-video-sdk/src/main/java/com/tencent/xnet
mv ../android/cpp/native-lib.cpp    device_video_aar/explorer-device-video-sdk/src/main/cpp/app-native-lib.cpp
sed -i '/\/\/xxxxxxJNI_OnLoad & JNI_OnUnload xxxxxx/, +30d' device_video_aar/explorer-device-video-sdk/src/main/cpp/app-native-lib.cpp
mv samples/iot_video_demo/app_interface/appWrapper.h   device_video_aar/explorer-device-video-sdk/src/main/cpp
mv samples/iot_video_demo/app_interface/app_log.h      device_video_aar/explorer-device-video-sdk/src/main/cpp
