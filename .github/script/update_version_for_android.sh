#!/bin/bash

rtt=$GIT_BRANCH_IMAGE_VERSION
rc=$(git rev-parse --short HEAD)
rb=$(git rev-parse --abbrev-ref HEAD)
# 获取当前分支的最新tag
currtag=$(git describe --tags --match "v[0-9]*" --abbrev=0 HEAD)
currbra=$rb
echo 000---$currtag
echo 111---$rtt
echo 222---$rc
echo 333---$rb

# ==========此处添加版本自增逻辑，如果是持续集成发snapshot，最新tag+1；如果是发布就发branch
vtag=${currtag#*v}
echo $vtag


branch=${currbra#*v}
vbranch=${branch%x*}0
echo $vbranch

function version_ge(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1";
}

resultvv=$vbranch
if version_ge $vtag $vbranch; then

    echo "$vtag is greater than or equal to $vbranch"

    vtaglist=(${vtag//./ })

    firsttag=${vtaglist[0]}
    secondtag=${vtaglist[1]}
    thirdtag=${vtaglist[2]}
    thirdtag=`expr $thirdtag + 1`

    resultvv=$firsttag.$secondtag.$thirdtag
fi

echo "-->>$resultvv"

#if [ "$1" = "Debug" ]; then
#	sed -i 's#def libVersion.*#def libVersion = \"'$resultvv'-SNAPSHOT\"#g' iot-p2p/samples/android/xnet/build.gradle
#else
#	sed -i 's#def libVersion.*#def libVersion = \"'$vtag'\"#g' iot-p2p/samples/android/xnet/build.gradle
#fi
if [ "$1" = "Debug" ]; then
    sed -i 's#def libVersion.*#def libVersion = \"'$resultvv'-SNAPSHOT\"#g' iot-p2p/android_device/device_video_aar/explorer-device-video-sdk/build.gradle
else
    sed -i 's#def libVersion.*#def libVersion = \"'$vtag'\"#g' iot-p2p/android_device/device_video_aar/explorer-device-video-sdk/build.gradle
fi
# ==========此处添加版本自增逻辑，如果是持续集成发snapshot，最新tag+1；如果是发布就发branch


