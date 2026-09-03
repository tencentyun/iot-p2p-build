set PATH=%PATH%;C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64
dir "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build"

cd iot-p2p


mkdir build
cd build

set sed="C:\Program Files\Git\usr\bin\sed.exe"

call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\Tools\VsDevCmd.bat"
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat"
cmake -DCMAKE_BUILD_TYPE=Release -DENET_NO_STATIC_BINARY=ON -DWITH_DHT=OFF -DBUILD_WITH_FS=ON -DWITH_ZIP=OFF -DENET_VERSION=lts_1.3  -G"Visual Studio 16 2019" -Tv142 -Ax64 ..
echo ================end-1======================
cmake --build . --config Release
echo ================end-2======================

cd ../iot/link/pc_app

REM 编译 app_interface 库
cp -r ../app_common/app_p2p      app_interface/app_p2p
cp -r ../app_common/cloud_api    app_interface/cloud_api
cp -r ../app_common/curl_inc     app_interface/curl
cp -r ../app_common/utils        app_interface/utils

mkdir build
cd build

cmake .. -DCOMPILE_SYSTEM=windows -DSYSTEM_ARCH=x64 -DCOMPILE_TYPE=Release -DCMAKE_BUILD_TYPE=Release  -G"Visual Studio 16 2019" -Tv142 -Ax64 ..
cmake --build . --config Release

ls -l ../p2p_sample/
