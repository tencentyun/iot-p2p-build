#!/bin/sh
# 说明：Ubuntu 20.04 兼容版构建脚本
# 与 build_enet_linux.sh 逻辑保持一致，额外打印产物的 GLIBC 依赖版本，方便验证兼容性
# 该脚本设计为在 ubuntu:20.04 Docker 容器内运行（由 libxp2p_linux_u2004.yml 驱动）

#set -eo pipefail
set -e

rtt=$GIT_BRANCH_IMAGE_VERSION
rc=$(git rev-parse --short HEAD)
rb=$(git rev-parse --abbrev-ref HEAD)
currtag=$(git describe --tags --match "v[0-9]*" --abbrev=0 HEAD)
currbra=$rb
echo 000---$currtag
echo 111---$rtt
echo 222---$rc
echo 333---$rb

# 打印当前编译环境的 glibc 版本，理论上应为 2.31（Ubuntu 20.04）
echo "=== Build env glibc version ==="
ldd --version || true
echo "==============================="

# 1.拉取eNet支持库
git clone https://$GIT_ACCESS_TOKEN@github.com/tencentyun/iot-p2p.git
cd iot-p2p

#2. 切换分支
if [ "$1" = 'Debug' ]; then
    git checkout $rb --
else
    git checkout $rtt
fi

#3. 获取pp版本号
VIDEOSDKRC=$(git rev-parse --short HEAD)
VIDEOSDKVERSION=$rb+git.$VIDEOSDKRC
if [ "$1" = 'Release' ]; then
    VIDEOSDKVERSION=$rtt+git.$VIDEOSDKRC
fi
VIDEOSDKVERSION=${VIDEOSDKVERSION#*v}
echo $VIDEOSDKVERSION


# 2.编译Linux平台工程配置
mkdir -p build

cd build

sed -i "s/.*VIDEOSDKVERSION.*/static const char * VIDEOSDKVERSION = \"$VIDEOSDKVERSION\";/g" ../iot/link/app_common/app_p2p/appWrapper.h

#编译enet库
cmake -DCOMPILE_SYSTEM=Linux -DCMAKE_BUILD_TYPE=Release -DENET_NO_STATIC_BINARY=ON -DBUNDLE_CERTS=OFF -DWITH_DHT=OFF -DBUILD_WITH_FS=ON -DWITH_ZIP=OFF -DENABLE_TCP_PUNCH=ON -DENET_VERSION=lts_1.3 ..
cmake --build . --config Release

cd ../iot/link/pc_app

#编译app_interface库
cp -r ../app_common/app_p2p      app_interface/app_p2p
cp -r ../app_common/cloud_api    app_interface/cloud_api
cp -r ../app_common/curl_inc     app_interface/curl
cp -r ../app_common/utils        app_interface/utils

mkdir build
cd build

cmake .. -DCOMPILE_SYSTEM=linux -DSYSTEM_ARCH=x86 -DCOMPILE_TYPE=Release
cmake --build . --config Release
ls -l ../p2p_sample/

# 检查产物的 GLIBC 依赖版本，最高应不超过 2.31（Ubuntu 20.04 的 glibc 版本）
echo "=== Check GLIBC symbols required by artifacts ==="
cd ../p2p_sample/
for f in $(find . -type f \( -name "*.so" -o -perm -u+x \) 2>/dev/null); do
    if file "$f" 2>/dev/null | grep -q "ELF"; then
        echo "--- $f ---"
        (objdump -T "$f" 2>/dev/null | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -u) || true
    fi
done
echo "================================================="

poddatetime=$(date '+%Y%m%d%H%M')
echo $poddatetime
