#!/bin/sh

version=$(tail -n 1 .github/file/android_release_version.txt)

if [ "$version" = "snapshot" ]; then
  echo "publish snapshot"
else
  echo "publish release"
  sed -i 's#def libVersion.*#def libVersion = \"'$version'\"#g' iot-p2p/samples/android/xnet/build.gradle
fi
