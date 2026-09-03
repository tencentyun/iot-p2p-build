#!/usr/bin/env bash
#
# Build libcurl 8.11.0 as an iOS static library.
#
# TLS backend : Apple SecureTransport (system Security.framework)
# Compression : Depends on system libz (not embedded)
# Deployment  : iOS 12.0+
# Slices      : arm64 (iOS device), arm64 (iOS simulator), x86_64 (iOS simulator)
# Outputs     :
#   /tmp/curl-build/output/libcurl.a              (fat, 3 slices)
#   /tmp/curl-build/output/libcurl.xcframework    (device + simulator)
#   /tmp/curl-build/output/include/curl/*.h       (public headers)
#
# Usage: bash build_curl_ios.sh

set -euo pipefail

CURL_VERSION="8.11.0"
MIN_IOS="12.0"

BUILD_ROOT="/tmp/curl-build"
SRC_TARBALL="${BUILD_ROOT}/curl-${CURL_VERSION}.tar.xz"
SRC_DIR="${BUILD_ROOT}/curl-${CURL_VERSION}"
OUT_DIR="${BUILD_ROOT}/output"
STAGE_DIR="${BUILD_ROOT}/stage"

DEV_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
CC="$(xcrun --sdk iphoneos --find clang)"

# Note: Do NOT use -fembed-bitcode / -fembed-bitcode-marker here.
# Xcode 14+ deprecated bitcode and Xcode 15+/26 linker rejects it outright:
#   ld: file cannot be open()ed, errno=2 path=marker in 'marker'
# App Store also stopped accepting bitcode submissions in 2023.
COMMON_CFLAGS="-Wno-deprecated-declarations -Os"

# Portable common configure flags (no OpenSSL, no third-party libs; SecureTransport + system libz only)
COMMON_CONFIGURE_FLAGS=(
  --disable-shared
  --enable-static
  --with-secure-transport
  --without-libpsl
  --without-brotli
  --without-zstd
  --without-libidn2
  --without-nghttp2
  --without-nghttp3
  --without-ngtcp2
  --without-quiche
  --without-libssh2
  --without-libssh
  --without-librtmp
  --without-libgsasl
  --with-zlib
  --disable-ldap
  --disable-ldaps
  --disable-manual
  --disable-docs
  --disable-verbose
)

mkdir -p "${BUILD_ROOT}" "${OUT_DIR}" "${STAGE_DIR}"

# 1. Fetch source (skip if already there)
if [[ ! -d "${SRC_DIR}" ]]; then
  if [[ ! -f "${SRC_TARBALL}" ]]; then
    echo ">>> Downloading curl ${CURL_VERSION} ..."
    curl -fL --retry 3 -o "${SRC_TARBALL}" "https://curl.se/download/curl-${CURL_VERSION}.tar.xz"
  fi
  echo ">>> Extracting ..."
  ( cd "${BUILD_ROOT}" && tar -xf "${SRC_TARBALL}" )
fi

build_slice() {
  local ARCH="$1"        # arm64 | x86_64
  local PLATFORM="$2"    # iphoneos | iphonesimulator
  local HOST="$3"        # arm-apple-darwin | x86_64-apple-darwin
  local SDK_PATH SDK_FLAG

  if [[ "${PLATFORM}" == "iphoneos" ]]; then
    SDK_PATH="${DEV_SDK}"
    SDK_FLAG="-mios-version-min=${MIN_IOS}"
  else
    SDK_PATH="${SIM_SDK}"
    SDK_FLAG="-mios-simulator-version-min=${MIN_IOS}"
  fi

  local TAG="${ARCH}-${PLATFORM}"
  local BUILD_DIR="${STAGE_DIR}/build-${TAG}"
  local PREFIX_DIR="${STAGE_DIR}/prefix-${TAG}"

  echo ""
  echo "=================================================================="
  echo ">>> Building slice: ${TAG}"
  echo "=================================================================="

  rm -rf "${BUILD_DIR}" "${PREFIX_DIR}"
  mkdir -p "${BUILD_DIR}"

  (
    cd "${BUILD_DIR}"

    export CC="${CC}"
    # Preprocessor must see the SDK sysroot too, otherwise configure's
    # "is prototyped" checks (which invoke $ac_cpp) fail with
    #   fatal error: 'sys/types.h' file not found
    # and downstream feature checks (fcntl / ioctl / freeaddrinfo / ftruncate ...)
    # get wrongly marked "no", eventually breaking lib/nonblock.c compilation with:
    #   #error "no non-blocking method was found/used/set"
    export CPP="${CC} -E"
    export CPPFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} ${SDK_FLAG}"
    export CFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} ${SDK_FLAG} ${COMMON_CFLAGS}"
    export LDFLAGS="-arch ${ARCH} -isysroot ${SDK_PATH} ${SDK_FLAG} -framework CoreFoundation -framework Security -framework SystemConfiguration"

    "${SRC_DIR}/configure" \
      --host="${HOST}" \
      --prefix="${PREFIX_DIR}" \
      "${COMMON_CONFIGURE_FLAGS[@]}" \
      > "configure-${TAG}.log" 2>&1 || { tail -n 80 "configure-${TAG}.log"; exit 1; }

    make -j"$(sysctl -n hw.ncpu)" > "make-${TAG}.log" 2>&1 || { tail -n 120 "make-${TAG}.log"; exit 1; }
    make install > "install-${TAG}.log" 2>&1
  )

  echo ">>> Built: ${PREFIX_DIR}/lib/libcurl.a"
}

# 2. Build all slices
build_slice arm64  iphoneos          arm-apple-darwin
build_slice arm64  iphonesimulator   arm-apple-darwin
build_slice x86_64 iphonesimulator   x86_64-apple-darwin

# 3. lipo fat libcurl.a (3 slices)
echo ""
echo "=================================================================="
echo ">>> Creating fat libcurl.a (3 slices) ..."
echo "=================================================================="
DEV_A="${STAGE_DIR}/prefix-arm64-iphoneos/lib/libcurl.a"
SIM_ARM_A="${STAGE_DIR}/prefix-arm64-iphonesimulator/lib/libcurl.a"
SIM_X86_A="${STAGE_DIR}/prefix-x86_64-iphonesimulator/lib/libcurl.a"

# fat libcurl.a can only contain unique architectures, and it is preserved here for
# users who still want a "drop-in replacement" of the original 5-slice libcurl.a.
# Two arm64 slices (device and simulator) cannot coexist in a single fat .a, so
# for the fat archive we prefer the device slice; simulator builds should use the xcframework.
lipo -create "${DEV_A}" "${SIM_X86_A}" -output "${OUT_DIR}/libcurl.a"
echo ">>> ${OUT_DIR}/libcurl.a"
lipo -info "${OUT_DIR}/libcurl.a"

# 4. Build xcframework (device slice + merged simulator slice)
echo ""
echo "=================================================================="
echo ">>> Creating libcurl.xcframework ..."
echo "=================================================================="
SIM_MERGED_A="${STAGE_DIR}/libcurl-sim.a"
lipo -create "${SIM_ARM_A}" "${SIM_X86_A}" -output "${SIM_MERGED_A}"

# Public headers are identical between slices; pick the device one.
HEADERS_DIR="${STAGE_DIR}/prefix-arm64-iphoneos/include"

rm -rf "${OUT_DIR}/libcurl.xcframework"
xcodebuild -create-xcframework \
  -library "${DEV_A}"        -headers "${HEADERS_DIR}" \
  -library "${SIM_MERGED_A}" -headers "${HEADERS_DIR}" \
  -output "${OUT_DIR}/libcurl.xcframework" >/dev/null

# 5. Copy public headers to output/include/curl for reference
rm -rf "${OUT_DIR}/include"
mkdir -p "${OUT_DIR}/include"
cp -R "${HEADERS_DIR}/curl" "${OUT_DIR}/include/curl"

echo ""
echo "=================================================================="
echo ">>> All done."
echo "     fat  libcurl.a       : ${OUT_DIR}/libcurl.a"
echo "     xcframework          : ${OUT_DIR}/libcurl.xcframework"
echo "     public headers       : ${OUT_DIR}/include/curl"
echo "=================================================================="
