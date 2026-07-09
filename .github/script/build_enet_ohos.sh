#!/bin/sh
set -e

# ==============================================================================
# 编译 iot-p2p 的 OHOS 静态库（arm64-v8a 与 armeabi-v7a）
# 产物：libenet.a / libevent*.a / libmbedtls*.a / libminizip.a / libtinyxml2.a
# 产物拷贝到：iot-p2p/iot/device/ohos_device/lib/<arch>/
# ==============================================================================

rb=$(git rev-parse --abbrev-ref HEAD)
echo $rb
echo $GIT_BRANCH_IMAGE_VERSION

# OHOS Native SDK 路径（CI 通过环境变量注入；本地未设置时使用 DevEco Studio 默认路径）
DEVECO_SDK="${DEVECO_SDK:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native}"
TOOLCHAIN_FILE="${DEVECO_SDK}/build/cmake/ohos.toolchain.cmake"
export PATH="${DEVECO_SDK}/build-tools/cmake/bin:$PATH"

[ -f "${TOOLCHAIN_FILE}" ] || { echo "[ERR] OHOS 工具链不存在: ${TOOLCHAIN_FILE}"; exit 1; }
command -v cmake >/dev/null || { echo "[ERR] cmake 未找到"; exit 1; }

# 1.拉取 eNet 支持库
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

# 2.准备产物目录
mkdir -p iot/device/ohos_device/lib/arm64-v8a
mkdir -p iot/device/ohos_device/lib/armeabi-v7a

# 3.编译 arm64-v8a
mkdir -p build/ohos_arm64
cd build/ohos_arm64
cmake ../.. \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    -DOHOS_PLATFORM=OHOS \
    -DOHOS_STL=c++_static \
    -DOHOS_ARCH=arm64-v8a \
    -DCMAKE_SYSTEM_NAME=OHOS \
    -DCMAKE_BUILD_TYPE=Release \
    -DENET_SELF_SIGN=ON \
    -DENET_VERSION=v1.0.0 \
    -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python3
make -j8

cd ../../
# 4.编译 armeabi-v7a
mkdir -p build/ohos_armv7
cd build/ohos_armv7
cmake ../.. \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    -DOHOS_PLATFORM=OHOS \
    -DOHOS_STL=c++_static \
    -DOHOS_ARCH=armeabi-v7a \
    -DCMAKE_SYSTEM_NAME=OHOS \
    -DCMAKE_BUILD_TYPE=Release \
    -DENET_SELF_SIGN=ON \
    -DENET_VERSION=v1.0.0 \
    -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python3
make -j8

cd ../../
# 5.汇总产物到 iot/device/ohos_device/lib/<arch>/
mv build/ohos_arm64/libenet.a                         iot/device/ohos_device/lib/arm64-v8a
mv build/ohos_arm64/_deps/libevent-build/*.a          iot/device/ohos_device/lib/arm64-v8a 2>/dev/null || true
mv build/ohos_arm64/_deps/mbedtls-build/library/*.a   iot/device/ohos_device/lib/arm64-v8a 2>/dev/null || true
mv build/ohos_arm64/_deps/minizip-build/*.a           iot/device/ohos_device/lib/arm64-v8a 2>/dev/null || true
mv build/ohos_arm64/_deps/tinyxml2-build/*.a          iot/device/ohos_device/lib/arm64-v8a 2>/dev/null || true

mv build/ohos_armv7/libenet.a                         iot/device/ohos_device/lib/armeabi-v7a
mv build/ohos_armv7/_deps/libevent-build/*.a          iot/device/ohos_device/lib/armeabi-v7a 2>/dev/null || true
mv build/ohos_armv7/_deps/mbedtls-build/library/*.a   iot/device/ohos_device/lib/armeabi-v7a 2>/dev/null || true
mv build/ohos_armv7/_deps/minizip-build/*.a           iot/device/ohos_device/lib/armeabi-v7a 2>/dev/null || true
mv build/ohos_armv7/_deps/tinyxml2-build/*.a          iot/device/ohos_device/lib/armeabi-v7a 2>/dev/null || true

ls -l iot/device/ohos_device/lib/arm64-v8a/
ls -l iot/device/ohos_device/lib/armeabi-v7a/