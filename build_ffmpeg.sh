#!/usr/bin/env bash

target_windows=false;
target_android=false;
debug=false;
enable_ffplay=false;
enable_ffprobe=false;
enable_x264=false;
enable_x265=false;
enable_ffnvcodec=false;
enable_vmaf=false;
enable_shared=false;
enable_static=false;
enable_multi_threaded_nienc=false;
enable_gstreamer_support=false;
dry_run_mode=false;
android_arch=x86_64
custom_flags="";
extra_config_flags=""

# parse a flag with an arg in or after it
# $1 flag pattern, $2 entire flag arg, $3 arg after flag arg
# return 1 if path is in second arg (separated by space), else return 0. Store path in $extract_arg_ret
extract_arg () {
    unset extract_arg_ret
    # check valid arg flag
    if [ -n "$(printf "%s" ${2} | grep -Eoh "${1}")" ]; then
        # check if path string is connected by '=' or is in following arg
        if [ -n "$(echo "${2}" | grep -Eoh "${1}=")" ]; then
            arg_str=`printf "%s" "${2}" | grep -Poh "${1}=\K.+"`;
            # trim out leading and trailing quotation marks
            extract_arg_ret=`echo "${arg_str}" | sed -e 's/^\(["'\'']\)//' -e 's/\(["'\'']\)$//'`;
            return 0;
        elif [ -n "$(printf "%s" ${2} | grep -Eoh "^${1}$")" ]; then
            arg_str="${3}";
            # trim out leading and trailing quotation marks
            extract_arg_ret=`printf "%s" "${arg_str}" | sed -e 's/^\(["'\'']\)//' -e 's/\(["'\'']\)$//'`;
            return 1;
        else
            echo "Unknown option '$2', exiting";
            exit 1;
        fi
    else
        echo "Target flag '$1' not found in '$2', exiting"; exit 1;
    fi
}

if [ `whoami` = root ]; then
    read -p "Do you wish to execute with sudo [Y/N]? " -n 1 -r
    echo   
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit
    fi
fi

while [ "$1" != "" ]; do
    case $1 in
        -h | --help) echo "Usage: ./build_ffmpeg.sh [OPTION]";
                     echo "Compile FFmpeg for T408.";
                     echo "Example: ./build_ffmpeg.sh";
                     echo;
                     echo "Options:";
                     echo "-h, --help                    display this help and exit.";
                     echo "-w, windows                   compile for Windows.";
                     echo "-a, --android                 compile for Android NDK.";
                     echo "-g, --gdb                     compile for GDB.";
                     echo "--ffplay                      compile with ffplay (requires libsdl2 package).";
                     echo "--ffprobe                     compile with ffprobe.";
                     echo "--libx264                     compile with libx264 (requires libx264 package).";
                     echo "--libx265                     compile with libx265 (requires libx265 package).";
                     echo "--ffnvcodec                   compile with ffnvcodec (requires ffnvcodec package).";
                     echo "--vmaf                        compile with vmaf (requires libvmaf).";
                     echo "--shared                      compile with shared libFF components.";
                     echo "--static                      compile entirely static.";
                     echo "--gstreamer                   compile with Netint GStreamer support (FFmpeg 4.3.1 only).";
                     echo "--nienc_multi_thread          compile nienc in libavcodec with multithreaded frame send/receive (experimental).";
                     echo "--dry                         dry run printing configs without building";
                     echo "--android_arch \"<arch>\"       cross compile CPU arch when compiling for --android. [arm,arm64,x86,x86_64(default)]";
                     echo "--custom_flags \"<flags>\"      compile with custom configuration flags";
                     echo "";
                     echo "T408 required configuration flags:";
                     echo "--enable-libxcoder_logan --enable-ni_logan --enable-gpl";
                     echo "--extra-ldflags='-lm -ldl'";
                     echo "--enable-pthreads --extra-libs='-lpthread'";
                     echo "--enable-x86asm";
                     exit 0
        ;;
        -w | windows)          target_windows=true
        ;;
        -a | --android)        target_android=true
        ;;
        -g | --gdb)            debug=true
        ;;
        --ffplay)              enable_ffplay=true
        ;;
        --ffprobe)             enable_ffprobe=true
        ;;
        --libx264)             enable_x264=true
        ;;
        --libx265)             enable_x265=true
        ;;
        --ffnvcodec)           enable_ffnvcodec=true
        ;;
        --vmaf)                enable_vmaf=true
        ;;
        --shared)              enable_shared=true
        ;;
        --static)              enable_static=true
        ;;
        --gstreamer)           enable_gstreamer_support=true
        ;;
        --nienc_multi_thread)  enable_multi_threaded_nienc=true
        ;;
        --dry)                 dry_run_mode=true
        ;;
        --android_arch | --android_arch=*) extract_arg "\-\-android_arch" "$1" "$2"; prev_rc=$?;
                                           if [ "$prev_rc" -eq 1 ]; then shift; fi
                                           android_arch=$extract_arg_ret
        ;;
        --custom_flags | --custom_flags=*) extract_arg "\-\-custom_flags" "$1" "$2"; prev_rc=$?;
                                           if [ "$prev_rc" -eq 1 ]; then shift; fi
                                           custom_flags=$extract_arg_ret
        ;;
        *)                     echo "Usage: ./build_ffmpeg.sh [OPTION]...";
                               echo "Try './build_ffmpeg.sh --help' for more information"; exit 1
        ;;
    esac
    shift
done

if $debug; then
    extra_config_flags="${extra_config_flags} --disable-optimizations --disable-asm --disable-stripping --enable-debug=3"
else
    extra_config_flags="${extra_config_flags} --enable-x86asm --disable-debug"
fi

if $enable_ffplay; then
    extra_config_flags="${extra_config_flags} --enable-ffplay"
else
    extra_config_flags="${extra_config_flags} --disable-ffplay"
fi

if $enable_ffprobe; then
    extra_config_flags="${extra_config_flags} --enable-ffprobe"
else
    extra_config_flags="${extra_config_flags} --disable-ffprobe"
fi

if $enable_x264; then
    extra_config_flags="${extra_config_flags} --enable-libx264"
else
    extra_config_flags="${extra_config_flags} --disable-libx264"
fi

if $enable_x265; then
    extra_config_flags="${extra_config_flags} --enable-libx265"
else
    extra_config_flags="${extra_config_flags} --disable-libx265"
fi

if $enable_ffnvcodec; then
    extra_config_flags="${extra_config_flags} --extra-cflags=-I/usr/local/cuda/targets/x86_64-linux/include --extra-ldflags=-L/usr/local/cuda/targets/x86_64-linux/lib --enable-cuda-nvcc --enable-cuda --enable-cuvid --enable-nvdec --enable-nvenc"
else
    extra_config_flags="${extra_config_flags} --disable-cuda-nvcc --disable-cuda --disable-cuvid --disable-nvdec --disable-nvenc"
fi

if $enable_vmaf; then
    extra_config_flags="${extra_config_flags} --enable-libvmaf --enable-version3"
else
    extra_config_flags="${extra_config_flags} --disable-libvmaf"
fi

if $enable_shared; then
    if $enable_static; then
        echo -e "\e[31mCannot use --shared and --static together. Exiting...\e[0m"
        exit 1
    fi
    extra_config_flags="${extra_config_flags} --disable-static --enable-shared --extra-cflags=-DXCODER_DLL"
else
    extra_config_flags="${extra_config_flags} --enable-static --disable-shared --extra-cflags=-UXCODER_DLL"
fi

if $enable_static; then
    extra_config_flags="${extra_config_flags} --enable-static --disable-shared --extra-cflags=-static --extra-ldflags=-static"
fi

if $enable_multi_threaded_nienc; then
    extra_config_flags="${extra_config_flags} --extra-cflags=-DNIENC_MULTI_THREAD"
else
    extra_config_flags="${extra_config_flags} --extra-cflags=-UNIENC_MULTI_THREAD"
fi

if $enable_gstreamer_support; then
    extra_config_flags="${extra_config_flags} --extra-cflags=-DNI_DEC_GSTREAMER_SUPPORT"
else
    extra_config_flags="${extra_config_flags} --extra-cflags=-UNI_DEC_GSTREAMER_SUPPORT"
fi


extra_config_flags="${extra_config_flags} ${custom_flags}"

if $target_windows; then
    if $dry_run_mode; then # Dry-run mode args is a separate duplicate of wet-run mode args due to bash quotation passing limitations
        echo ./configure \
        --enable-cross-compile --arch='x86_64' \
        --target-os='mingw32' \
        --pkg-config-flags='--static' \
        --enable-gpl --enable-nonfree \
        --extra-ldflags='-lm' \
        --enable-libxcoder_logan \
        --enable-ni_logan \
        --enable-w32threads --extra-libs=\'-lwinpthread -lws2_32\' \
        --enable-encoders --enable-decoders --enable-avfilter --enable-muxers --enable-demuxers --enable-parsers \
        ${extra_config_flags}
    else # Dry-run mode args is a separate duplicate of wet-run mode args due to bash quotation passing limitations
        ./configure \
        --enable-cross-compile --arch='x86_64' \
        --target-os='mingw32' \
        --pkg-config-flags='--static' \
        --enable-gpl --enable-nonfree \
        --extra-ldflags='-lm' \
        --enable-libxcoder_logan \
        --enable-ni_logan \
        --enable-w32threads --extra-libs='-lwinpthread -lws2_32' \
        --enable-encoders --enable-decoders --enable-avfilter --enable-muxers --enable-demuxers --enable-parsers \
        ${extra_config_flags}
        if [ $? != 0 ]; then
            echo -e "\e[31mConfiguration failed. Exiting...\e[0m"
            exit 1
        else
            make -j $(nproc)
            . ./mingw_package_ffmpeg.sh
            RC=$?
        fi
    fi
elif $target_android; then

    echo "android_arch: ${android_arch}"

    if [ -z ${ANDROID_NDK_ROOT} ]; then
        echo "You must set ANDROID_NDK_ROOT environment variable"
        echo "Please download NDK r20b from https://developer.android.com/ndk/downloads/older_releases"
        exit -1
    fi

    if [ "${android_arch}" = "arm" ]; then
        ARCH=arm
        ARCH2=armv7-a
        CPU=armv7-a
    elif [ "${android_arch}" = "arm64" ]; then
        ARCH=arm64
        ARCH2=aarch64
        CPU=armv8-a
    elif [ "${android_arch}" = "x86" ]; then
        ARCH=x86
        ARCH2=i686
        CPU=i686
    elif [ "${android_arch}" = "x86_64" ]; then
        ARCH=x86_64
        ARCH2=x86_64
        CPU=x86_64
    elif [ "${android_arch}" = "" ]; then
        ARCH=x86_64
        ARCH2=x86_64
        CPU=x86_64
    else
        echo "Error - unknown option for --android_arch. Select from: [arm,arm64,x86,x86_64]"
        exit -1
    fi

    echo "Building android ARCH=${ARCH}"

    API=28
    TOOLCHAIN=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64
    PREFIX=android/$ARCH

    if $dry_run_mode; then # Dry-run mode args is a separate duplicate of wet-run mode args due to bash quotation passing limitations
        echo ./configure \
        --prefix=$PREFIX \
        --enable-cross-compile \
        --sysroot=$TOOLCHAIN/sysroot \
        --arch=$ARCH2 \
        --cpu=$CPU \
        --target-os='android' \
        --cc=$TOOLCHAIN/bin/$ARCH2-linux-android$API-clang \
        --cross-prefix=$TOOLCHAIN/bin/$ARCH2-linux-android- \
        --pkg-config=$(which pkg-config) \
        --pkg-config-flags='--static' \
        --enable-gpl --enable-nonfree \
        --extra-ldflags=\'-fuse-ld=gold -lm\' \
        --enable-libxcoder_logan \
        --enable-ni_logan \
        --extra-libs=-lgcc \
        --enable-pic \
        --extra-cflags=\'-DANDROID -D_ANDROID -D__ANDROID__\' \
        --enable-pthreads \
        --enable-encoders --enable-decoders --enable-avfilter --enable-muxers --enable-demuxers --enable-parsers \
        ${extra_config_flags}
    else # Dry-run mode args is a separate duplicate of wet-run mode args due to bash quotation passing limitations
        ./configure \
        --prefix=$PREFIX \
        --enable-cross-compile \
        --sysroot=$TOOLCHAIN/sysroot \
        --arch=$ARCH2 \
        --cpu=$CPU \
        --target-os='android' \
        --cc=$TOOLCHAIN/bin/$ARCH2-linux-android$API-clang \
        --cross-prefix=$TOOLCHAIN/bin/$ARCH2-linux-android- \
        --pkg-config=$(which pkg-config) \
        --pkg-config-flags='--static' \
        --enable-gpl --enable-nonfree \
        --extra-ldflags='-fuse-ld=gold -lm' \
        --enable-libxcoder_logan \
        --enable-ni_logan \
        --extra-libs=-lgcc \
        --enable-pic \
        --extra-cflags='-DANDROID -D_ANDROID -D__ANDROID__' \
        --enable-pthreads \
        --enable-encoders --enable-decoders --enable-avfilter --enable-muxers --enable-demuxers --enable-parsers \
        ${extra_config_flags}
        if [ $? != 0 ]; then
            echo -e "\e[31mConfiguration failed. Exiting...\e[0m"
            exit 1
        else
            make -j $(nproc)
            RC=$?
        fi
    fi
else
    if $dry_run_mode; then # Dry-run mode args is a separate duplicate of wet-run mode args due to bash quotation passing limitations
        echo ./configure \
        --pkg-config-flags='--static' \
        --enable-gpl --enable-nonfree \
        --extra-ldflags='-lm' --extra-ldflags='-ldl' \
        --enable-libxcoder_logan \
        --enable-ni_logan \
        --enable-pthreads --extra-libs='-lpthread' \
        --enable-encoders --enable-decoders --enable-avfilter --enable-muxers --enable-demuxers --enable-parsers \
        ${extra_config_flags}
    else # Dry-run mode args is a separate duplicate of wet-run mode args due to bash quotation passing limitations
        ./configure \
        --pkg-config-flags='--static' \
        --enable-gpl --enable-nonfree \
        --extra-ldflags='-lm' --extra-ldflags='-ldl' \
        --enable-libxcoder_logan \
        --enable-ni_logan \
        --enable-pthreads --extra-libs='-lpthread' \
        --enable-encoders --enable-decoders --enable-avfilter --enable-muxers --enable-demuxers --enable-parsers \
        ${extra_config_flags}
        if [ $? != 0 ]; then
            echo -e "\e[31mConfiguration failed. Exiting...\e[0m"
            exit 1
        else
            make -j $(nproc)
            RC=$?
        fi
    fi
fi

if $enable_shared && [ ! -z $RC ] && [ $RC -eq 0 ]; then
    echo "Reminder: after installing FFmpeg, run 'sudo ldconfig' to cache the shared libraries"
fi
exit $RC
