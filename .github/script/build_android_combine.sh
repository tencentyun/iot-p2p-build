
#!/bin/sh
set -e  # 建议：任何一步失败立即退出，避免继续在错误状态下执行

rb=$(git rev-parse --abbrev-ref HEAD)
echo $rb
echo $GIT_BRANCH_IMAGE_VERSION

# 1.拉取 iot-p2p 源码仓库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p
if [ "$1" = "Release" ]; then
    git checkout $GIT_BRANCH_IMAGE_VERSION
else
    git checkout $rb
fi

# 1.1 获取 p2p 版本号
VIDEOSDKRC=$(git rev-parse --short HEAD)
rc=$rb+git.$VIDEOSDKRC
if [ "$1" = "Release" ]; then
    rc=$GIT_BRANCH_IMAGE_VERSION+git.$VIDEOSDKRC
fi
rc=${rc#*v}
echo $rc

# 2. 拷贝 app_interface 源文件至 android_device/samples/iot_video_demo
# 【改动 ⑤】mkdir 加 -p，避免目录已存在时报错
mkdir -p iot/device/android_device/samples/iot_video_demo/app_interface
mv iot/link/app_common/curl_inc/*   iot/device/android_device/samples/iot_video_demo/app_interface
mv iot/link/app_common/app_p2p/*    iot/device/android_device/samples/iot_video_demo/app_interface
mv iot/link/app_common/cloud_api/*  iot/device/android_device/samples/iot_video_demo/app_interface
mv iot/link/app_common/utils/*      iot/device/android_device/samples/iot_video_demo/app_interface
#rm iot/device/android_device/samples/iot_video_demo/app_interface/utils_hmac.cpp

# 2.1 更新 p2p 代码版本
sed -i "s#.*VIDEOSDKVERSION.*#static const char * VIDEOSDKVERSION = \"$rc\";#g" \
    iot/device/android_device/samples/iot_video_demo/app_interface/appWrapper.h

mv ../.github/file/libs/arm64-v8a/libcurl.a    iot/device/android_device/lib/arm64-v8a
mv ../.github/file/libs/armeabi-v7a/libcurl.a  iot/device/android_device/lib/armeabi-v7a

# 3. 编译 iot_video_demo.so（含依赖静态库 libenet.a 等）
# 【改动 ③】追加 -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON，与上层 build.gradle 保持一致
mkdir -p build/android_arm64
cd build/android_arm64
cmake ../.. \
  -DCMAKE_TOOLCHAIN_FILE=/usr/local/lib/android/sdk/ndk/27.3.13750724/build/cmake/android.toolchain.cmake \
  -DANDROID_NDK=/usr/local/lib/android/sdk/ndk/27.3.13750724 \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_NATIVE_API_LEVEL=21 \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_STL=c++_static \
  -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON
make -j8

cd ../../
mkdir -p build/android_armv7
cd build/android_armv7
cmake ../.. \
  -DCMAKE_TOOLCHAIN_FILE=/usr/local/lib/android/sdk/ndk/27.3.13750724/build/cmake/android.toolchain.cmake \
  -DANDROID_NDK=/usr/local/lib/android/sdk/ndk/27.3.13750724 \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_NATIVE_API_LEVEL=21 \
  -DANDROID_ABI=armeabi-v7a \
  -DANDROID_STL=c++_static \
  -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON
make -j8

cd ../../
mv build/android_arm64/libenet.a                         iot/device/android_device/lib/arm64-v8a
mv build/android_arm64/_deps/libevent-build/*.a          iot/device/android_device/lib/arm64-v8a
mv build/android_arm64/_deps/mbedtls-build/library/*.a   iot/device/android_device/lib/arm64-v8a
mv build/android_arm64/_deps/minizip-build/*.a           iot/device/android_device/lib/arm64-v8a
mv build/android_arm64/_deps/tinyxml2-build/*.a          iot/device/android_device/lib/arm64-v8a

mv build/android_armv7/libenet.a                         iot/device/android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/libevent-build/*.a          iot/device/android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/mbedtls-build/library/*.a   iot/device/android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/minizip-build/*.a           iot/device/android_device/lib/armeabi-v7a
mv build/android_armv7/_deps/tinyxml2-build/*.a          iot/device/android_device/lib/armeabi-v7a

# 3.1 进入 android_device 目录，编译 libiot_video_demo.so
cd iot/device/android_device
./cmake_build.sh ANDROID

ls -l output/arm64-v8a/
ls -l output/armeabi-v7a/

# 4. 移动头文件、libiot_video_demo.so 到 explorer-app-video-sdk
# 【改动 ④】此时 pwd 已经在 iot/device/android_device 下，路径前缀必须去掉，
# 否则会因为路径不存在而失败（对照脚本末尾被注释掉的老版本，路径写法就是相对的）
mv samples/iot_video_demo/app_interface/appWrapper.h   device_video_aar/explorer-app-video-sdk/src/main/cpp
mv samples/iot_video_demo/app_interface/app_log.h      device_video_aar/explorer-app-video-sdk/src/main/cpp

# 编译 app xp2p sdk（把 libiot_video_demo.so 放到 aar 工程的 libs/ 下）
mv output/armeabi-v7a/libiot_video_demo.so   device_video_aar/explorer-app-video-sdk/libs/armeabi-v7a
mv output/arm64-v8a/libiot_video_demo.so     device_video_aar/explorer-app-video-sdk/libs/arm64-v8a

# ============================================================
# 【新增 ⑧】产物验证：确认 libiot_video_demo.so 不再依赖 libc++_shared.so
# 若 CI 环境有 llvm-readelf，可解开下面这段做校验，失败直接退出
# ============================================================
# READELF=/usr/local/lib/android/sdk/ndk/27.3.13750724/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf
# for abi in arm64-v8a armeabi-v7a; do
#     SO=device_video_aar/explorer-app-video-sdk/libs/$abi/libiot_video_demo.so
#     echo "=== $SO NEEDED ==="
#     $READELF -d $SO | grep NEEDED
#     if $READELF -d $SO | grep -q libc++_shared.so; then
#         echo "ERROR: $SO still depends on libc++_shared.so"
#         exit 1
#     fi
# done

# 4. 构建打包 aar 所需要的 app 头文件以及 native-lib.cpp 文件（暂未启用）
#mv ../../link/android_app/java/*.java           device_video_aar/explorer-device-video-sdk/src/main/java/com/tencent/xnet
#mv ../../link/android_app/cpp/native-lib.cpp    device_video_aar/explorer-device-video-sdk/src/main/cpp/app-native-lib.cpp
#sed -i '/\/\/xxxxxxJNI_OnLoad & JNI_OnUnload xxxxxx/, +30d' device_video_aar/explorer-device-video-sdk/src/main/cpp/app-native-lib.cpp
#mv samples/iot_video_demo/app_interface/appWrapper.h   device_video_aar/explorer-device-video-sdk/src/main/cpp
#mv samples/iot_video_demo/app_interface/app_log.h      device_video_aar/explorer-device-video-sdk/src/main/cpp
