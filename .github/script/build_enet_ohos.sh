#!/bin/sh
set -e

# ==============================================================================
# 编译 iot-p2p 的 OHOS 静态库（arm64-v8a 与 armeabi-v7a）
# 产物：libenet.a / libevent*.a / libmbedtls*.a / libminizip.a / libtinyxml2.a
# 自动拷贝到当前工程 libiotvideo/libs/<arch>/ 供 libiotvideo.so 链接
# ==============================================================================

# ---- 路径配置（支持通过环境变量覆盖，未设置时使用本机默认值）-----------------
P2P_SRC_DIR="${P2P_SRC_DIR:-/Users/heyu/project/iot-p2p}"
DEVECO_SDK="${DEVECO_SDK:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native}"
DEMO_LIBS_DIR="${DEMO_LIBS_DIR:-/Users/heyu/DevEcoStudioProjects/iot_video_demo/libiotvideo/libs}"

TOOLCHAIN_FILE="${DEVECO_SDK}/build/cmake/ohos.toolchain.cmake"
export PATH="${DEVECO_SDK}/build-tools/cmake/bin:$PATH"

# ---- 环境校验 ----------------------------------------------------------------
[ -d "${P2P_SRC_DIR}" ]     || { echo "[ERR] P2P 源码目录不存在: ${P2P_SRC_DIR}"; exit 1; }
[ -f "${TOOLCHAIN_FILE}" ]  || { echo "[ERR] OHOS 工具链不存在: ${TOOLCHAIN_FILE}"; exit 1; }
command -v cmake >/dev/null || { echo "[ERR] cmake 未找到，请检查 DevEco SDK 路径"; exit 1; }

mkdir -p "${DEMO_LIBS_DIR}/arm64-v8a"
mkdir -p "${DEMO_LIBS_DIR}/armeabi-v7a"

cd "${P2P_SRC_DIR}"

# ---- 通用编译函数 ------------------------------------------------------------
# 参数: $1=OHOS_ARCH   $2=build 子目录名   $3=目标 libs 目录
build_one_arch() {
    OHOS_ARCH="$1"
    BUILD_DIR="build/$2"
    DEST_DIR="$3"

    echo ""
    echo "=============================================================="
    echo "[BUILD] arch=${OHOS_ARCH}  build_dir=${BUILD_DIR}"
    echo "=============================================================="

    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    (
        cd "${BUILD_DIR}"
        cmake "${P2P_SRC_DIR}" \
            -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
            -DOHOS_PLATFORM=OHOS \
            -DOHOS_STL=c++_static \
            -DOHOS_ARCH="${OHOS_ARCH}" \
            -DCMAKE_SYSTEM_NAME=OHOS \
            -DCMAKE_BUILD_TYPE=Release \
            -DENET_SELF_SIGN=ON \
            -DENET_VERSION=v1.0.0 \
            -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python3
        make all -j8
    )

    echo "[COPY] -> ${DEST_DIR}"
    # 主库
    cp -f "${BUILD_DIR}"/libenet.a                             "${DEST_DIR}/"
    # 第三方依赖（FetchContent 编出来的）
    cp -f "${BUILD_DIR}"/_deps/libevent-build/*.a              "${DEST_DIR}/" 2>/dev/null || true
    cp -f "${BUILD_DIR}"/_deps/mbedtls-build/library/*.a       "${DEST_DIR}/" 2>/dev/null || true
    cp -f "${BUILD_DIR}"/_deps/minizip-build/*.a               "${DEST_DIR}/" 2>/dev/null || true
    cp -f "${BUILD_DIR}"/_deps/tinyxml2-build/*.a              "${DEST_DIR}/" 2>/dev/null || true
}

# ---- 依次编两个架构 ----------------------------------------------------------
build_one_arch "arm64-v8a"    "ohos_arm64" "${DEMO_LIBS_DIR}/arm64-v8a"
build_one_arch "armeabi-v7a"  "ohos_armv7" "${DEMO_LIBS_DIR}/armeabi-v7a"

echo ""
echo "=============================================================="
echo "[DONE] 全部编译完成，产物已拷贝到:"
echo "  ${DEMO_LIBS_DIR}/arm64-v8a"
echo "  ${DEMO_LIBS_DIR}/armeabi-v7a"
echo "=============================================================="
ls -1 "${DEMO_LIBS_DIR}/arm64-v8a"    | sed 's/^/  arm64-v8a  : /'
ls -1 "${DEMO_LIBS_DIR}/armeabi-v7a"  | sed 's/^/  armeabi-v7a: /'
