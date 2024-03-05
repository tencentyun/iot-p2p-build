#set PATH=%PATH%;C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x86
dir "C:\Program Files (x86)\Microsoft Visual Studio"
dir "C:\Program Files (x86)\Microsoft Visual Studio\2019"
dir "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise"
dir "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\Tools"
dir "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build"
set rtt=%2

for /F %%i in ('git rev-parse --short HEAD') do ( set commitid=%%i)
set rc=%commitid%

for /F %%i in ('git rev-parse --abbrev-ref HEAD') do ( set commitid=%%i)
set rb=%commitid%

for /F %%i in ('git describe --tags --match "v[0-9]*" --abbrev=0 HEAD') do ( set commitid=%%i)
set currtag=%commitid%

set currbra=%rb%

echo 000---%currtag%
echo 111---%rtt%
echo 222---%rc%
echo 333---%rb%


for /F %%i in ('call echo https://%%GIT_ACCESS_TOKEN%%@github.com/tencentyun/iot-p2p.git') do ( set commitid=%%i)
set url=%commitid%

git clone %url%
cd iot-p2p

if  %1==Debug (
    git checkout %rb% --
) else (
    git checkout %rtt%
)

for /F %%i in ('git rev-parse --short HEAD') do ( set commitid=%%i)
set VIDEO_SDK_RC=%commitid%
set VIDEO_SDK_VERSION=%rb%+git.%VIDEO_SDK_RC%

if  %1==Release (
    set VIDEO_SDK_VERSION=%rtt%+git.%VIDEO_SDK_RC%
)
set VIDEO_SDK_VERSION=%VIDEO_SDK_VERSION:~1%
echo %VIDEO_SDK_VERSION%

mkdir build
cd build

set sed="C:\Program Files\Git\usr\bin\sed.exe"

%sed% -i "s/.*VIDEOSDKVERSION.*/static const char * VIDEOSDKVERSION = \"%VIDEO_SDK_VERSION%\";/g" ../iot/link/app_common/app_p2p/appWrapper.h

call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\VsDevCmd.bat"
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars32.bat"
cmake -DCMAKE_BUILD_TYPE=Release -DENET_NO_STATIC_BINARY=ON -DWITH_DHT=OFF -DBUILD_WITH_FS=OFF -DWITH_ZIP=OFF -DENET_VERSION=lts_1.3  -G"Visual Studio 16 2019" -Tv142 -AWin32 ..
echo ================end-1======================
cmake --build . --config Release
echo ================end-2======================

cd ../iot/link/pc_app

#编译app_interface库
cp -r ../app_common/app_p2p      app_interface/app_p2p
cp -r ../app_common/cloud_api    app_interface/cloud_api
cp -r ../app_common/curl_inc     app_interface/curl
cp -r ../app_common/utils        app_interface/utils

mkdir build
cd build

cmake .. -DCOMPILE_SYSTEM=windows -DSYSTEM_ARCH=x86 -DCOMPILE_TYPE=Release -DCMAKE_BUILD_TYPE=Release  -G"Visual Studio 16 2019" -Tv142 -AWin32 ..
cmake --build . --config Release

ls -l ../p2p_sample/
