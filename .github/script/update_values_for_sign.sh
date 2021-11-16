#!/bin/sh

key_id=$KEY_ID_OF_SIGN
password=$PASSWORD_OF_SIGN
root_path=$(pwd)
sed -i 's#MY_KEY_ID#'$key_id'#g' iot-p2p/samples/android/gradle.properties
sed -i 's#MY_PASSWORD#'$password'#g' iot-p2p/samples/android/gradle.properties
sed -i 's#MY_KEY_RING_FILE#'$root_path'/secring.gpg#g' iot-p2p/samples/android/gradle.properties

#device android
sed -i 's#MY_KEY_ID#'$key_id'#g' iot-p2p/android_device/device_video_aar/gradle.properties
sed -i 's#MY_PASSWORD#'$password'#g' iot-p2p/android_device/device_video_aar/gradle.properties
sed -i 's#MY_KEY_RING_FILE#'$root_path'/secring.gpg#g' iot-p2p/android_device/device_video_aar/gradle.properties
