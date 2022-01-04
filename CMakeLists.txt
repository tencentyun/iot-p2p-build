cmake_minimum_required(VERSION 3.15.0)
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
option(ENET_UNITY_BUILD OFF "Use Unity Build, only available when cmake > 3.16")
if (CMAKE_SYSTEM_NAME MATCHES "iOS")
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/tools/ios/ios.toolchain.cmake")
    if (NOT CMAKE_VERSION VERSION_LESS 3.16.0)
        set(HAS_OBJC TRUE)
        enable_language(OBJC OBJCXX)
    else ()
        set(HAS_OBJC FALSE)
    endif ()
endif ()
project(eNet)

# Configure CCache if available
if (NOT DEFINED CCACHE)
    find_program(CCACHE ccache)
endif ()
if (CCACHE AND NOT MSVC AND NOT CCACHE_DISABLE)
    set(CCACHE_ENABLED ON)
endif ()
if (CCACHE_ENABLED)
    message("use cache compiler ${CCACHE}")
    set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE}")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE}")
    if (XCODE)
        configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/cc.in" cc)
        configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/cxx.in" cxx)
        execute_process(COMMAND chmod +x "${CMAKE_CURRENT_BINARY_DIR}/cc" "${CMAKE_CURRENT_BINARY_DIR}/cxx")
        set(CMAKE_XCODE_ATTRIBUTE_CC "${CMAKE_CURRENT_BINARY_DIR}/cc")
        set(CMAKE_XCODE_ATTRIBUTE_CXX "${CMAKE_CURRENT_BINARY_DIR}/cxx")
        set(CMAKE_XCODE_ATTRIBUTE_LD "${CMAKE_CURRENT_BINARY_DIR}/cc")
        set(CMAKE_XCODE_ATTRIBUTE_LDPLUSPLUS "${CMAKE_CURRENT_BINARY_DIR}/cxx")
    endif ()
endif ()

# cmake -DCMAKE_BUILD_TYPE=Debug/Release ..
if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif ()

option(WITH_MEMPOOL "Build with Memory Pool" OFF)
if (WITH_MEMPOOL)
    add_definitions(-DMEMPOOL)
endif ()

option(WITH_EVDNS "Build with evdns" ON)
if (WITH_EVDNS)
    add_definitions(-DENABLE_EVDNS)
endif ()

option(NO_LOG "Disable all log" OFF)
if (NO_LOG)
    add_definitions(-DNO_LOG)
endif ()

option(WITH_REGEX "Build with std::regex" ON)
if (WITH_REGEX)
    add_definitions(-DWITH_REGEX)
endif ()

option(SYSTEM_UCLIBC "uClibc system" OFF)
if (SYSTEM_UCLIBC)
    add_compile_options(-DUCLIBC)
    set(WITH_BOOSTFUNCTION ON)
    add_definitions(-DBOOST_NO_CXX11_ALLOCATOR)
    add_definitions(-DBOOST_NO_CXX11_HDR_TYPEINDEX)
    add_definitions(-DBOOST_NO_CXX11_HDR_SYSTEM_ERROR)
    add_definitions(-DBOOST_NO_CXX11_HDR_ARRAY)
    add_definitions(-DBOOST_NO_CXX11_HDR_TUPLE)
    add_definitions(-DBOOST_NO_STD_WSTRING)
    add_definitions(-DBOOST_NO_CXX11_SMART_PTR)
    add_definitions(-DBOOST_NO_VOID_RETURNS)
    add_definitions(-DBOOST_NO_CXX11_CHAR16_T)
    add_definitions(-DBOOST_NO_CXX11_CHAR32_T)
    #boost::function中很多地方依赖gnuc版本判断，而uclibc又是经过裁剪的，版本高但是功能不全，这里强制设置版本
    add_definitions(-D__GNUC__=4)
    add_definitions(-D__GNUC_MINOR__=5)
endif ()

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "CMAKE_SYSTEM_NAME = ${CMAKE_SYSTEM_NAME}")
message(STATUS "ENET_VERSION = ${ENET_VERSION}")
message(STATUS "ENET_CLIENT = ${ENET_CLIENT}")
message(STATUS "ENET_DEBUG= ${ENET_DEBUG}")
message(STATUS "ENET_COVERAGE= ${ENET_COVERAGE}")
message(STATUS "WITH_MEMPOOL= ${WITH_MEMPOOL}")

set(ENET__LIBRARY_TYPE DEFAULT CACHE STRING
        "Set library type to SHARED/STATIC/BOTH (default SHARED for MSVC, otherwise BOTH)")
set(ENET_LIBRARY_TYPE)
if ("${ENET__LIBRARY_TYPE}" STREQUAL "DEFAULT")
    if (${MSVC})
        set(ENET_LIBRARY_TYPE SHARED)
    else ()
        set(ENET_LIBRARY_TYPE BOTH)
    endif ()
else ()
    string(TOUPPER "${ENET__LIBRARY_TYPE}" ENET_LIBRARY_TYPE)
endif ()
set(ENET_LIBRARY_STATIC OFF)
set(ENET_LIBRARY_SHARED OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
if ("${ENET_LIBRARY_TYPE}" STREQUAL "BOTH")
    set(ENET_LIBRARY_STATIC ON)
    set(ENET_LIBRARY_SHARED ON)
elseif ("${ENET_LIBRARY_TYPE}" STREQUAL "STATIC")
    set(ENET_LIBRARY_STATIC ON)
elseif ("${ENET_LIBRARY_TYPE}" STREQUAL "SHARED")
    set(ENET_LIBRARY_SHARED ON)
else ()
    message(FATAL_ERROR "${ENET_LIBRARY_TYPE} is not supported")
endif ()

if (CMAKE_SYSTEM_NAME STREQUAL Linux)
    set(ENET_BINARY_STATIC_FLAGS "")
    set(ENET_SANITIZE "" CACHE STRING "address/thread/undefined")
    if (ENET_SANITIZE STREQUAL "address")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address")
        set(STATIC_SANITIZE_FLAG "-static-libasan")
    elseif (ENET_SANITIZE STREQUAL "thread")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=thread -pthread")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=thread -pthread")
        set(STATIC_SANITIZE_FLAG "-static-libtsan")
    elseif (ENET_SANITIZE STREQUAL "undefined")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=undefined")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=undefined")
        set(STATIC_SANITIZE_FLAG "-static-libubsan")
    elseif (NOT ENET_SANITIZE STREQUAL "")
        message(FATAL_ERROR "unknown sanitize ${ENET_SANITIZE}")
    endif ()
    if (STATIC_SANITIZE_FLAG)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            set(ENET_BINARY_STATIC_FLAGS "-static-libgcc;-static-libstdc++;-static-libsan")
        else ()
            set(ENET_BINARY_STATIC_FLAGS "-static-libgcc;-static-libstdc++;${STATIC_SANITIZE_FLAG}")
        endif ()
    else ()
        # 没有sanitize直接设置static
        set(ENET_BINARY_STATIC_FLAGS "-static;-Wl,--whole-archive;-lpthread;-Wl,--no-whole-archive")
    endif ()
endif ()

option(DISABLE_LTO "Disable LTO building" FALSE)
if (DISABLE_LTO OR ENET_SANITIZE)
    message("Disable LTO")
else ()
    include(CheckIPOSupported)
    check_ipo_supported(RESULT SUPPORT_IPO)
endif ()
if (SUPPORT_IPO)
    if (ANDROID)# android ndk has bug when lto https://github.com/android/ndk/issues/721
        message("Disable LTO for Android")
    elseif (CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 8.0)
        # lto on gcc 4.8 may lead gcc crash
        # lto on gcc 7 may lead some error
        message("Disable LTO for GCC Version < 8.0")
    else ()
        message("Enable LTO")
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_DEBUG OFF)
    endif ()
else ()
    message("Not support LTO")
endif ()

if (APPLE)
    add_link_options($<$<NOT:$<CONFIG:Debug>>:LINKER:-dead_strip>)
elseif (MSVC)
else ()
    add_compile_options($<$<NOT:$<CONFIG:Debug>>:-ffunction-sections>)
    add_compile_options($<$<NOT:$<CONFIG:Debug>>:-fdata-sections>)
    add_link_options($<$<NOT:$<CONFIG:Debug>>:LINKER:--gc-sections>)
endif ()

if ("${ENET_VERSION}" STREQUAL "")
    message(STATUS "ENET VERSION is empty, use default value in codes.")
else ()
    message(STATUS "ENET Version: ${ENET_VERSION}")
    add_compile_options(-DENET_VERSION=${ENET_VERSION})
endif ()

if ("${ENET_CLIENT}" STREQUAL "")
    message(STATUS "ENET CLIENT is empty, use default value in codes.")
else ()
    add_compile_options(-D${ENET_CLIENT})
endif ()

if ("${ENET_DEBUG}" STREQUAL "")
    message(STATUS "ENET DEBUG is empty. ")
else ()
    add_compile_options(-DENET_DEBUG)
endif ()

if (ENET_COVERAGE STREQUAL "gcov")
    add_compile_options($<$<CONFIG:Debug>:--coverage>)
    add_link_options($<$<CONFIG:Debug>:--coverage>)
    set(ENET_NO_STATIC_BINARY ON)
elseif (ENET_COVERAGE STREQUAL "llvm-cov")
    add_compile_options($<$<CONFIG:Debug>:-fprofile-instr-generate>)
    add_compile_options($<$<CONFIG:Debug>:-fcoverage-mapping>)
    add_link_options($<$<CONFIG:Debug>:-fprofile-instr-generate>)
    add_link_options($<$<CONFIG:Debug>:-fcoverage-mapping>)
    set(ENET_NO_STATIC_BINARY ON)
endif ()

set(ARCH "")
set(ARCH_LIB_STATIC_SUBFIX ".a")
set(ARCH_LIB_SHARED_SUBFIX ".so")
set(ARCH_LIB_PREFIX "lib")
cmake_policy(SET CMP0063 NEW)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN 1)

if (${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    if (NOT CMAKE_MSVC_RUNTIME_LIBRARY)
        SET(CMAKE_C_FLAGS_MTDEBUG ${CMAKE_C_FLAGS_DEBUG})
        SET(CMAKE_CXX_FLAGS_MTDEBUG ${CMAKE_CXX_FLAGS_DEBUG})
        SET(CMAKE_EXE_LINKER_FLAGS_MTDEBUG ${CMAKE_EXE_LINKER_FLAGS_DEBUG})
        SET(CMAKE_SHARED_LINKER_FLAGS_MTDEBUG ${CMAKE_SHARED_LINKER_FLAGS_DEBUG})
        SET(CMAKE_C_FLAGS_MTRELEASE ${CMAKE_C_FLAGS_RELEASE})
        SET(CMAKE_CXX_FLAGS_MTRELEASE ${CMAKE_CXX_FLAGS_RELEASE})
        SET(CMAKE_EXE_LINKER_FLAGS_MTRELEASE ${CMAKE_EXE_LINKER_FLAGS_RELEASE})
        SET(CMAKE_SHARED_LINKER_FLAGS_MTRELEASE ${CMAKE_SHARED_LINKER_FLAGS_RELEASE})
        SET(CMAKE_C_FLAGS_MTRELWITHDEBINFO ${CMAKE_C_FLAGS_RELWITHDEBINFO})
        SET(CMAKE_CXX_FLAGS_MTRELWITHDEBINFO ${CMAKE_CXX_FLAGS_RELWITHDEBINFO})
        SET(CMAKE_EXE_LINKER_FLAGS_MTRELWITHDEBINFO ${CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO})
        SET(CMAKE_SHARED_LINKER_FLAGS_MTRELWITHDEBINFO ${CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO})
        SET(CMAKE_C_FLAGS_MTMINSIZEREL ${CMAKE_C_FLAGS_MINSIZEREL})
        SET(CMAKE_CXX_FLAGS_MTMINSIZEREL ${CMAKE_CXX_FLAGS_MINSIZEREL})
        SET(CMAKE_EXE_LINKER_FLAGS_MTMINSIZEREL ${CMAKE_EXE_LINKER_FLAGS_MINSIZEREL})
        SET(CMAKE_SHARED_LINKER_FLAGS_MTMINSIZEREL ${CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL})
        MARK_AS_ADVANCED(
                CMAKE_C_FLAGS_MTDEBUG CMAKE_CXX_FLAGS_MTDEBUG CMAKE_EXE_LINKER_FLAGS_MTDEBUG CMAKE_SHARED_LINKER_FLAGS_MTDEBUG
                CMAKE_C_FLAGS_MTRELEASE CMAKE_CXX_FLAGS_MTRELEASE CMAKE_EXE_LINKER_FLAGS_MTRELEASE CMAKE_SHARED_LINKER_FLAGS_MTRELEASE
                CMAKE_C_FLAGS_MTRELWITHDEBINFO CMAKE_CXX_FLAGS_MTRELWITHDEBINFO CMAKE_EXE_LINKER_FLAGS_MTRELWITHDEBINFO CMAKE_SHARED_LINKER_FLAGS_MTRELWITHDEBINFO
                CMAKE_C_FLAGS_MTMINSIZEREL CMAKE_CXX_FLAGS_MTMINSIZEREL CMAKE_EXE_LINKER_FLAGS_MTMINSIZEREL CMAKE_SHARED_LINKER_FLAGS_MTMINSIZEREL
        )
        SET(CMAKE_CONFIGURATION_TYPES "Debug;RelWithDebInfo;MinSizeRel;Release;MTDebug;MTRelease;MTRelWithDebInfo;MTMinSizeRel" CACHE STRING "" FORCE)
        SET(MD_CONFIG "Debug$<SEMICOLON>RelWithDebInfo$<SEMICOLON>MinSizeRel$<SEMICOLON>Release")
        SET(DEBUG_CONFIG "Debug;MTDebug")
        SET(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded$<$<IN_LIST:$<CONFIG>,${DEBUG_CONFIG}>:Debug>$<$<IN_LIST:$<CONFIG>,${MD_CONFIG}>:DLL>)
    endif ()
    add_compile_options($<$<CXX_COMPILER_ID:MSVC>:/EHsc>)
    add_compile_options($<$<CXX_COMPILER_ID:MSVC>:/MP>)
    # Force to always compile with W4
    if (CMAKE_CXX_FLAGS MATCHES "/W[0-4]")
        string(REGEX REPLACE "/W[0-4]" "/W4" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    else ()
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W4")
    endif ()
    if (CMAKE_C_FLAGS MATCHES "/W[0-4]")
        string(REGEX REPLACE "/W[0-4]" "/W4" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
    else ()
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /W4")
    endif ()
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /wd4100 /wd4458 /wd4131")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4100 /wd4458 /wd4131")
    add_compile_options($<$<CXX_COMPILER_ID:MSVC>:/utf-8>)

    set(SYSTEM_WINDOWS TRUE)
    add_compile_options(-DWINDOWS)
    add_compile_options(-DNOMINMAX)
    set(ARCH "windows")
    set(ARCH_LIB_STATIC_SUBFIX ".lib")
    set(ARCH_LIB_PREFIX "")
    add_compile_options(-DZLIB_WINAPI)
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    if (SYSTEM_OPENWRT)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_C99") # for std::to_string
        add_compile_definitions(OPENWRT _GNU_SOURCE)
        set(ARCH "openwrt")
    else ()
        set(SYSTEM_LINUX TRUE)
        add_compile_definitions(DEVICE_x86)
        set(ARCH "linux")
    endif ()
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(SYSTEM_MACOSX TRUE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET 10.12.4)
    add_compile_options(-DMAC_OSX)
    set(ARCH "macos")
elseif (${CMAKE_SYSTEM_NAME} MATCHES "iOS")
    if (${ENET_VERSION} MATCHES "^v([0-9]|[1-9][0-9]+)(\\.([0-9]|[1-9][0-9]+))*$")
        string(SUBSTRING ${ENET_VERSION} 1 -1 FRAMEWORK_BUNDLE_VERSION)
        message(STATUS "FRAMEWORK_BUNDLE_VERSION = ${FRAMEWORK_BUNDLE_VERSION}")
    else ()
        message(FATAL_ERROR "ENET_VERSION = ${ENET_VERSION}, iOS version format should be v#.#.#, E.G v5.1.1")
    endif ()

    set(SYSTEM_IOS TRUE)
    add_compile_definitions(IOS)
    set(ARCH "ios")
    set(CMAKE_XCODE_ATTRIBUTE_EXCLUDED_ARCHS[sdk=iphonesimulator*] "arm64 arm64e")
    if (NOT CMAKE_OSX_ARCHITECTURES)
        if (XCODE)
            set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "" FORCE)
        else ()
            if (${CMAKE_OSX_SYSROOT} MATCHES "iPhoneOS")
                set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "" FORCE)
            else ()
                set(CMAKE_OSX_ARCHITECTURES "x86_64" CACHE STRING "" FORCE)
            endif ()
        endif ()
    endif ()
    if (NOT XCODE)
        set(CMAKE_INSTALL_NAME_DIR "@rpath")
        set(CMAKE_BUILD_WITH_INSTALL_NAME_DIR ON)
    endif ()
    set(CMAKE_IOS_INSTALL_COMBINED ON)
    set(CMAKE_OSX_DEPLOYMENT_TARGET 9.0)
    # XCode use IPHONEOS_DEPLOYMENT_TARGET
    set(CMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "9.0")
    set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO")
    # -fno-exception doesn't work in ios XCode project
    set(CMAKE_XCODE_ATTRIBUTE_GCC_ENABLE_CPP_EXCEPTIONS "NO")
    set(CMAKE_XCODE_ATTRIBUTE_GCC_ENABLE_OBJC_EXCEPTIONS "NO")
    set(CMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym")
    set(CMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")
    set(DEVELOPMENT_TEAM_ID "")
    set(CODE_SIGN_IDENTITY "iPhone Developer")

    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ${CODE_SIGN_IDENTITY})
    set(CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ${DEVELOPMENT_TEAM_ID})
    set(DEVICE_FAMILY "1")                                      # Set to "1" to target iPhone, set to "2" to target iPad
    set(CMAKE_XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY ${DEVICE_FAMILY})

    option(ENABLE_BITCODE "Build with Bitcode" ON)
    if (ENABLE_BITCODE)
        if (XCODE)
            set(CMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE YES)
            set(CMAKE_XCODE_ATTRIBUTE_BITCODE_GENERATION_MODE "bitcode")
        else ()
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fembed-bitcode")
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fembed-bitcode")
            set(CMAKE_OBJC_FLAGS "${CMAKE_OBJC_FLAGS} -fembed-bitcode")
            set(CMAKE_OBJCXX_FLAGS "${CMAKE_OBJCXX_FLAGS} -fembed-bitcode")
        endif ()
    elseif (XCODE)
        set(CMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE NO)
    endif ()

elseif (${CMAKE_SYSTEM_NAME} MATCHES "Android")
    set(SYSTEM_ANDROID TRUE)
    add_compile_options(-DANDROID)
    set(ARCH "android-9/${ANDROID_ABI}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DTARGET_ARCH_ABI=${ANDROID_ABI}")
endif ()

include(cmake/ThirdParty.cmake)

# get git commit
include(cmake/GetGitRevisionDescription.cmake)
set(ENET_COMMITID "")
get_git_hash(ENET_COMMITID)
# 蓝盾:https://iwiki.oa.tencent.com/pages/viewpage.action?pageId=15106147
if (DEFINED ENV{BK_CI_GIT_REPO_HEAD_COMMIT_ID})
    set(ENET_COMMITID $ENV{BK_CI_GIT_REPO_HEAD_COMMIT_ID})
endif ()
# ORANGE:http://doc.orange-ci.oa.com/env.html
if (DEFINED ENV{ORANGE_COMMIT})
    set(ENET_COMMITID $ENV{ORANGE_COMMIT})
endif ()
if ("${ENET_COMMITID}" STREQUAL "")
    message(STATUS "Git Hash commit is empty, use Unknown.")
    set(ENET_COMMITID "Unknown")
endif ()
add_compile_definitions(ENET_COMMITID=${ENET_COMMITID})
message(STATUS "ENET_COMMITID = ${ENET_COMMITID}")

message(STATUS "CMAKE_EXE_LINKER_FLAGS: ${CMAKE_EXE_LINKER_FLAGS}")

# print all warning message
if (NOT SYSTEM_IOS)
    SET(CMAKE_C_EXTENSIONS OFF) #'-std=gnu99' not allowed with 'Objective-C++'
endif ()

SET(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -DDEBUG")   # -g
SET(CMAKE_C_FLAGS_MINSIZEREL "${CMAKE_C_FLAGS_MINSIZEREL}") # -Os -DNDEBUG
SET(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}") # -O2 -g -DNDEBUG

if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND NOT MSVC AND CMAKE_VERSION VERSION_LESS 3.15.2)
    # Fix some bugly cmake version https://gitlab.kitware.com/cmake/cmake/issues/19515
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++14")
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND ANDROID AND NOT CMAKE_CXX_COMPILER_VERSION)
    # Fix ndk version < 14 don't set CMAKE_CXX_COMPILER_VERSION
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++14")
    # higher cxx standard may lead to upgrade iOS/macOS min version
    # android now use gnustl which has no higher cxx standard support
elseif (cxx_std_20 IN_LIST CMAKE_CXX_COMPILE_FEATURES AND NOT APPLE AND NOT ANDROID)
    SET(CMAKE_CXX_STANDARD 20)
elseif (cxx_std_17 IN_LIST CMAKE_CXX_COMPILE_FEATURES AND NOT APPLE AND NOT ANDROID)
    SET(CMAKE_CXX_STANDARD 17)
elseif (cxx_std_14 IN_LIST CMAKE_CXX_COMPILE_FEATURES)
    SET(CMAKE_CXX_STANDARD 14)
elseif (cxx_std_11 IN_LIST CMAKE_CXX_COMPILE_FEATURES)
    SET(CMAKE_CXX_STANDARD 11)
else ()
    message(FATAL_ERROR "compiler must support c++11")
endif ()

set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -DDEBUG")
set(CMAKE_CXX_FLAGS_MINSIZEREL "${CMAKE_CXX_FLAGS_MINSIZEREL}")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
if (NOT MSVC)
    SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -Wno-unused-parameter -fmessage-length=0")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-unused-parameter")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions -fmessage-length=0")
    if ("${CMAKE_BUILD_TYPE}" STREQUAL "DEBUG")
        add_compile_options(-Werror)
    endif ()
endif ()
if (APPLE)
    SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wunguarded-availability -Wunguarded-availability-new")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wunguarded-availability -Wunguarded-availability-new")
endif ()

if (SYSTEM_IOS)
    #treat .cpp files as objective-c codes.
    file(GLOB_RECURSE SHOULD_BE_OC_FILES Logger.cpp)
    if (HAS_OBJC)
        set_property(SOURCE ${SHOULD_BE_OC_FILES} PROPERTY LANGUAGE OBJCXX)
    else ()
        set_property(SOURCE ${SHOULD_BE_OC_FILES} APPEND PROPERTY COMPILE_OPTIONS -x objective-c++)
    endif ()
endif ()

message(STATUS "CMAKE_C_COMPILER: ${CMAKE_C_COMPILER}")
message(STATUS "CMAKE_C_FLAGS: ${CMAKE_C_FLAGS}")
message(STATUS "CMAKE_C_FLAGS_DEBUG: ${CMAKE_C_FLAGS_DEBUG}")
message(STATUS "CMAKE_C_FLAGS_RELEASE: ${CMAKE_C_FLAGS_RELEASE}")
message(STATUS "CMAKE_C_FLAGS_MINSIZEREL: ${CMAKE_C_FLAGS_MINSIZEREL}")
message(STATUS "CMAKE_C_FLAGS_RELWITHDEBINFO: ${CMAKE_C_FLAGS_RELWITHDEBINFO}")

message(STATUS "CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER}")
message(STATUS "CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")
message(STATUS "CMAKE_CXX_FLAGS_DEBUG: ${CMAKE_CXX_FLAGS_DEBUG}")
message(STATUS "CMAKE_CXX_FLAGS_RELEASE: ${CMAKE_CXX_FLAGS_RELEASE}")
message(STATUS "CMAKE_CXX_FLAGS_MINSIZEREL: ${CMAKE_CXX_FLAGS_MINSIZEREL}")
message(STATUS "CMAKE_CXX_FLAGS_RELWITHDEBINFO: ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
option(ENABLE_LINT "Enable Lint tools" OFF)
if (ENABLE_LINT)
    # set(CMAKE_LINK_WHAT_YOU_USE ON)

    if (NOT CLANG_TIDY)
        find_program(CLANG_TIDY clang-tidy)
    endif ()
    if (CLANG_TIDY)
        message("found clang-tidy: ${CLANG_TIDY}")
        set(CMAKE_C_CLANG_TIDY "${CLANG_TIDY};--warnings-as-errors=*")
        set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY};--warnings-as-errors=*")
    endif ()

    # if(NOT CPPCHECK)
    # find_program(CPPCHECK cppcheck)
    # endif()
    # if(CPPCHECK)
    # message("found cppcheck: ${CPPCHECK}")
    # set(CMAKE_C_CPPCHECK "${CPPCHECK}")
    # set(CMAKE_CXX_CPPCHECK "${CPPCHECK}")
    # endif()

    # if(NOT CPPLINT)
    # find_program(CPPLINT NAMES cpplint cpplint.py)
    # endif()
    # if(CPPLINT)
    # message("found cpplint: ${CPPLINT}")
    # set(CMAKE_C_CPPLINT "${CPPLINT}")
    # set(CMAKE_CXX_CPPLINT "${CPPLINT}")
    # endif()

    # if (NOT IWYU)
    # find_program(IWYU NAMES iwyu iwyu_tool.py)
    # endif ()
    # if (IWYU)
    # message("found iwyu: ${IWYU}")
    # set(CMAKE_C_INCLUDE_WHAT_YOU_USE "${IWYU}")
    # set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE "${IWYU}")
    # endif ()
endif ()

file(GLOB_RECURSE CORE_FILES
        "src/net/*"
        "src/framework/*"
        "src/http/*"
        "src/service/*"
        )

option(WITH_DHT "With DHT support" ON)
if (WITH_DHT)
    file(GLOB_RECURSE CORE_FILES
            ${CORE_FILES}
            "src/resource/*"
            "src/xdfs/*"
            "src/dht/*"
            "src/app_interface/*"
            )
endif ()

if (WITH_MEMPOOL)
    file(GLOB_RECURSE CORE_FILES
            ${CORE_FILES}
            "src/mempool/*"
            )
endif ()

file(GLOB_RECURSE EXTENSION_FILES
        "extension/*.h"
        "extension/*.hpp"
        "extension/*.c"
        "extension/*.cpp")

file(GLOB_RECURSE NAT_TEST_FILES
        test/net/VirtnetTest.cpp
        )
file(GLOB_RECURSE NET_TEST_FILES
        test/net/DetectorTest.cpp
        test/node/TrackerTest.cpp
        test/http/HttpRequestTest.cpp
        )
file(GLOB_RECURSE TEST_FILES
        "test/*.cpp"
        "test/*.h"
        "test/*.hpp"
        )
list(REMOVE_ITEM TEST_FILES ${NAT_TEST_FILES} ${NET_TEST_FILES} ${TEST_NAT_FILES})
list(APPEND NET_TEST_FILES test/main.cpp)
list(APPEND NAT_TEST_FILES test/main.cpp)

file(GLOB_RECURSE MEMPOOL_TEST_FILES
        "test/mempool/*"
        )

file(GLOB_RECURSE SAMPLE_IPC_FILES "samples/ipc/*")
file(GLOB_RECURSE SAMPLE_HELLO_FILES "samples/hello.cpp")
file(GLOB_RECURSE SAMPLE_HTTP_CLIENT_FILES "samples/http-client.cpp")
file(GLOB_RECURSE SAMPLE_HTTP_SERVER_FILES "samples/http-server.cpp")
file(GLOB_RECURSE SAMPLE_HTTP_PROXY_FILES "samples/http-proxy.cpp")
file(GLOB_RECURSE SAMPLE_NAT_DETECT_FILES "samples/nat/nat-detect.cpp")
file(GLOB_RECURSE SAMPLE_NAT_UPNP_FILES "samples/upnp-portmap.cpp")
file(GLOB_RECURSE SAMPLE_NAT_PUNCH_FILES "samples/nat/nat-punch.cpp")
file(GLOB_RECURSE SAMPLE_NAT_TRACKER_FILES "samples/nat/Tracker.cpp")

if (NOT WITH_MEMPOOL)
    list(REMOVE_ITEM TEST_FILES ${MEMPOOL_TEST_FILES})
endif ()

if (CMAKE_SYSTEM_NAME STREQUAL Linux)
    option(BUNDLE_CERTS "Bundle Mozilla CA Certs (for some linux has no cacerts)" ON)
endif ()
if (BUILD_WITH_TLS)
    include(cmake/GenerateAppleCerts.cmake)
    if (IOS)
        ExportCertFromApple()
    endif ()
    if (BUNDLE_CERTS)
        DownloadCertFromCurl()
        add_compile_definitions(BUNDLE_CERTS)
    endif ()
endif ()

set(LIB_NAME enet)
set(ADD_ENET_LIBRARY_TARGETS)
message(STATUS "ENET_LIBRARY_TYPE: ${ENET_LIBRARY_TYPE}")
if (ENET_UNITY_BUILD)
    set(CMAKE_UNITY_BUILD ON)
    set(CMAKE_UNITY_BUILD_BATCH_SIZE 0)
endif ()
if (XCODE OR ENET_UNITY_BUILD)
    # https://gitlab.kitware.com/cmake/cmake/issues/16577
    # Xcode generator has bug if there are duplicate name file.
    set(ENET_OBJECTS ${CORE_FILES} ${EXTENSION_FILES} ${PACK_FILES})
else ()
    add_library("${LIB_NAME}_objects" OBJECT ${CORE_FILES} ${EXTENSION_FILES} ${PACK_FILES})
    target_link_libraries("${LIB_NAME}_objects" ${THIRD_LIBS})
    # for android studio which couldn't recognize OBJECT library in cpp module
    if (ANDROID)
        add_library("${LIB_NAME}_dummy" SHARED EXCLUDE_FROM_ALL ${CORE_FILES} ${EXTENSION_FILES} ${PACK_FILES})
    endif ()
    # https://cmake.org/cmake/help/latest/command/add_library.html#object-libraries
    # use TARGET_OBJECTS should at least add a source file
    set(ENET_OBJECTS $<TARGET_OBJECTS:${LIB_NAME}_objects> ${CMAKE_CURRENT_SOURCE_DIR}/tools/ios/dummy.cpp)
endif ()
# Linux/Windows/MacOS/Android/IOS all need native lib
if (ENET_LIBRARY_SHARED)
    source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR} FILES ${CORE_FILES} ${EXTENSION_FILES} ${PACK_FILES})
    add_library("${LIB_NAME}_shared" SHARED ${ENET_OBJECTS})
    target_link_libraries("${LIB_NAME}_shared" ${THIRD_LIBS})
    if (APPLE)
        if (IOS) # iOS打包framework因此map需要向上一级生成，不在framework内
            target_link_options("${LIB_NAME}_shared" PRIVATE "LINKER:-map,$<TARGET_FILE_DIR:${LIB_NAME}_shared>.map")
        else ()
            target_link_options("${LIB_NAME}_shared" PRIVATE "LINKER:-map,$<TARGET_FILE:${LIB_NAME}_shared>.map")
        endif ()
    elseif (MSVC)
        target_link_options("${LIB_NAME}_shared" PRIVATE "LINKER:/MAP:$<TARGET_FILE:${LIB_NAME}_shared>.map")
    else ()
        target_link_options("${LIB_NAME}_shared" PRIVATE "LINKER:-Map=$<TARGET_FILE:${LIB_NAME}_shared>.map")
    endif ()
    set_target_properties("${LIB_NAME}_shared" PROPERTIES
            OUTPUT_NAME "${LIB_NAME}"
            CLEAN_DIRECT_OUTPUT 1
            PUBLIC_HEADER "${NATIVE_HDR_PUBLIC}")

    list(APPEND ADD_ENET_LIBRARY_TARGETS "${LIB_NAME}_shared")
    if (IOS)
        if (NOT XCODE)
            target_sources("${LIB_NAME}_shared" PUBLIC "${NATIVE_HDR_PUBLIC}")
        endif ()
        if (XCODE)
            add_custom_command(TARGET ${LIB_NAME}_shared POST_BUILD
                    COMMAND install_name_tool -id "@rpath/TencentENET.framework/TencentENET" $<TARGET_FILE:${LIB_NAME}_shared>)
        endif ()
        set_target_properties("${LIB_NAME}_shared" PROPERTIES
                OUTPUT_NAME TencentENET
                FRAMEWORK TRUE
                FRAMEWORK_VERSION A
                MACOSX_FRAMEWORK_IDENTIFIER "qcloud.TencentENET"
                MACOSX_FRAMEWORK_BUNDLE_VERSION ${FRAMEWORK_BUNDLE_VERSION}
                MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${FRAMEWORK_BUNDLE_VERSION}
                # "current version" in semantic format in Mach-O binary file
                VERSION 1.0.0
                # "compatibility version" in semantic format in Mach-O binary file
                SOVERSION 1.0.0
                PUBLIC_HEADER "${NATIVE_HDR_PUBLIC}"
                )
    endif ()
endif ()
if (ENET_LIBRARY_STATIC)
    source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR} FILES ${CORE_FILES} ${EXTENSION_FILES} ${PACK_FILES})
    add_library("${LIB_NAME}_static" STATIC ${ENET_OBJECTS})
    target_link_libraries("${LIB_NAME}_static" ${THIRD_LIBS})

    set_target_properties("${LIB_NAME}_static" PROPERTIES
            OUTPUT_NAME "${LIB_NAME}"
            CLEAN_DIRECT_OUTPUT 1
            PUBLIC_HEADER "${NATIVE_HDR_PUBLIC}")

    include(cmake/BundleStaticLibrary.cmake)
    list(APPEND ADD_ENET_LIBRARY_TARGETS "${LIB_NAME}_static")
    # bundle_static_library("${LIB_NAME}_static" "${LIB_NAME}_with_dependencies")
endif ()

message(STATUS "ADD_ENET_LIBRARY_TARGETS: ${ADD_ENET_LIBRARY_TARGETS}")
install(TARGETS ${ADD_ENET_LIBRARY_TARGETS}
        EXPORT ENETTargets
        LIBRARY DESTINATION "lib" COMPONENT lib
        ARCHIVE DESTINATION "lib" COMPONENT lib
        RUNTIME DESTINATION "lib" COMPONENT lib
        PUBLIC_HEADER DESTINATION "include/enet"
        FRAMEWORK DESTINATION "lib"
        COMPONENT dev
        )
# use install directory for keep directory hierarchy
install(DIRECTORY src/ DESTINATION ${CMAKE_INSTALL_PREFIX}/include/enet
        FILES_MATCHING PATTERN "*.h")
include(cmake/iOSCombinedSymbols.cmake)
include(cmake/iOSInstallName.cmake)
# xcode build combined library may modify install_name after install
if (XCODE AND IOS)
    if (ENET_LIBRARY_SHARED)
        FixInstallName(${LIB_NAME}_shared)
        CombinedFrameworkSymbols(${LIB_NAME}_shared)
    endif ()
    if (ENET_LIBRARY_STATIC)
        # 这里不以SCRIPT文件的方式执行，是因为SCRIPT方式不会展开$<CONFIG>原因未知
        install(CODE "execute_process(COMMAND libtool -static -o ${CMAKE_INSTALL_PREFIX}/lib/libenet_with_dependencies.a ${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>-iphoneos/libenet_with_dependencies.a ${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>-iphonesimulator/libenet_with_dependencies.a)")
    endif ()
endif ()

if (NOT IOS AND NOT ANDROID)
    if (ENET_UNITY_BUILD)
        set(CMAKE_UNITY_BUILD OFF)
    endif ()

    enable_testing()

    include_directories(${CMAKE_CURRENT_SOURCE_DIR}/test)

    add_library(enet-test ${CORE_FILES} ${EXTENSION_FILES} ${PACK_FILES})
    target_compile_definitions(enet-test PUBLIC ENET_TEST=1)
    target_link_libraries(enet-test PUBLIC ${THIRD_LIBS} ${THIRD_TEST_LIBS} gflags::gflags)

    if (ENET_BINARY_STATIC_FLAGS AND NOT ENET_NO_STATIC_BINARY)
        add_link_options("${ENET_BINARY_STATIC_FLAGS}")
    endif ()

    # 不依赖环境的单元测试
    add_executable(enet-unittest ${TEST_FILES})
    target_link_libraries(enet-unittest enet-test gflags::gflags)
    # 依赖docker网络的nat测试
    add_executable(enet-nat-test ${NAT_TEST_FILES})
    target_link_libraries(enet-nat-test enet-test gflags::gflags)
    # 依赖外网环境的测试
    add_executable(enet-net-test ${NET_TEST_FILES})
    target_link_libraries(enet-net-test enet-test gflags::gflags)

    add_library(enet-core ${CORE_FILES} ${EXTENSION_FILES} ${PACK_FILES})
    target_link_libraries(enet-core PUBLIC ${THIRD_LIBS})
    # punch sample
    add_executable(nat-punch ${SAMPLE_NAT_PUNCH_FILES})
    target_link_libraries(nat-punch enet-core)
    # mock tracker
    add_executable(nat-tracker ${SAMPLE_NAT_TRACKER_FILES})
    target_link_libraries(nat-tracker enet-core)
    # hello sample
    add_executable(hello ${SAMPLE_HELLO_FILES})
    target_link_libraries(hello enet-core)
    # http-client sample
    add_executable(http-client ${SAMPLE_HTTP_CLIENT_FILES})
    target_link_libraries(http-client enet-core)
    # http-server sample
    add_executable(http-server ${SAMPLE_HTTP_SERVER_FILES})
    target_link_libraries(http-server enet-core)
    # http-proxy sample
    add_executable(http-proxy ${SAMPLE_HTTP_PROXY_FILES})
    target_link_libraries(http-proxy enet-core)
    # nat-detect sample
    add_executable(nat-detect ${SAMPLE_NAT_DETECT_FILES})
    target_link_libraries(nat-detect enet-core)
    # upnp-portmap sample
    add_executable(upnp-portmap ${SAMPLE_NAT_UPNP_FILES})
    target_link_libraries(upnp-portmap enet-core)
    # ipc sample
    add_executable(ipcamera ${SAMPLE_IPC_FILES})
    target_link_libraries(ipcamera enet-core)

    add_test(unittest enet_client-test)
    option(ENABLE_DOCKER_TEST "enable test with docker" TRUE)
    if (ENABLE_DOCKER_TEST)
        execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/tools/nat ${CMAKE_CURRENT_BINARY_DIR}/nat_test)
        add_custom_command(TARGET enet-nat-test POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:enet-nat-test> ${CMAKE_CURRENT_BINARY_DIR}/nat_test)
        find_program(Docker_EXECUTABLE docker)
        if (Docker_EXECUTABLE)
            add_test(NAME dockertest
                    COMMAND ${Docker_EXECUTABLE} run -it --rm -v "${CMAKE_CURRENT_BINARY_DIR}/nat_test:/nat_test" -w /nat_test
                    --privileged csighub.tencentyun.com/p2p/test-nat:v2 ./run.sh ./enet-nat-test
                    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/nat_test)
        else ()
            message("Not found docker, disable docker test default")
        endif ()
    endif ()
endif ()

foreach (target ${ADD_ENET_LIBRARY_TARGETS} ${LIB_NAME}_objects enet-test enet-core enet-unittest enet-nat-test enet-net-test)
    if (NOT TARGET ${target})
        continue()
    endif ()
    target_include_directories(${target} SYSTEM PUBLIC ${THIRD_INCLUDE})
    target_include_directories(${target} PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/extension>
            $<INSTALL_INTERFACE:include/enet>
            )
    target_compile_definitions(${target} PUBLIC FMT_HEADER_ONLY)
endforeach ()
