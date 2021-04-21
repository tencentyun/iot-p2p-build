#!/bin/sh

rtt=$(git describe --tags `git rev-list --tags --max-count=1`)
rt=${rtt#*v}
sed -i 's#def libVersion.*#def libVersion = \"'$rt'\"#g' iot-p2p/samples/android/xnet/build.gradle
