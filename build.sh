#/bin/bash

set -e
set -x

SRC_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $SRC_PATH

if [ "$SNAPCRAFT_PART_INSTALL" != "" ]; then
    INSTALL=$SNAPCRAFT_PART_INSTALL
elif [ "$INSTALL_DIR" != "" ]; then
    INSTALL=$INSTALL_DIR
fi

if [ "$SNAPCRAFT_ARCH_TRIPLET" != "" ]; then
    ARCH_TRIPLET="$SNAPCRAFT_ARCH_TRIPLET"
fi

if [ "$INSTALL" == "" ]; then
    echo "Cannot find INSTALL, bailing..."
    exit 1
fi

# Internal variables
if [ -f /usr/bin/dpkg-architecture ]; then
    MULTIARCH=$(/usr/bin/dpkg-architecture -qDEB_TARGET_MULTIARCH)
else
    MULTIARCH=""
fi

# Architecture mapping for SailfishOS game code
if [ "$ARCH" == "arm64" ]; then
    SFOS_ARCH=aarch64
    SFOS_BIN_GAME=$SRC_DIR/game/Ports/Quake2/Output/Targets/SailfishOS-64/Release/bin/baseq2
    SFOS_BIN_ENGINE=$SRC_DIR/game/Ports/Quake2/Output/Targets/SailfishOS-64/Debug/bin/quake2-gles2
    export CC="aarch64-linux-gnu-gcc"
    export CXX="aarch64-linux-gnu-g++"
    export AR="aarch64-linux-gnu-ar"
elif [ "$ARCH" == "armhf" ]; then
    SFOS_ARCH=armv7hl
    SFOS_BIN_GAME=$SRC_DIR/game/Ports/Quake2/Output/Targets/SailfishOS-32/Release/bin/baseq2
    SFOS_BIN_ENGINE=$SRC_DIR/game/Ports/Quake2/Output/Targets/SailfishOS-32/Debug/bin/quake2-gles2
    export CC="arm-linux-gnueabihf-gcc"
    export CXX="arm-linux-gnueabihf-g++"
    export AR="arm-linux-gnueabihf-ar"
else
    SFOS_ARCH=x86_64
    SFOS_BIN_GAME=$SRC_DIR/game/Ports/Quake2/Output/Targets/SailfishOS-32-x86/Release/bin/baseq2
    SFOS_BIN_ENGINE=$SRC_DIR/game/Ports/Quake2/Output/Targets/SailfishOS-32-x86/Debug/bin/quake2-gles2
    export CC="x86_64-linux-gnu-gcc"
    export CXX="x86_64-linux-gnu-g++"
    export AR="x86_64-linux-gnu-ar"
fi

# Unset duplicate environment variables that screw with Quake2 Makefiles
unset ARCH

# pkg-config & m4 macros
PKG_CONF_SYSTEM=/usr/lib/$MULTIARCH/pkgconfig
PKG_CONF_INSTALL=$INSTALL/lib/pkgconfig:$INSTALL/share/pkgconfig:$INSTALL/lib/$MULTIARCH/pkgconfig
PKG_CONF_EXIST=$PKG_CONFIG_PATH
export PKG_CONFIG_PATH=$PKG_CONF_INSTALL:$PKG_CONF_SYSTEM
if [ "$PKG_CONF_EXIST" != "" ]; then
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$PKG_CONF_EXIST"
fi
export ACLOCAL_PATH=$INSTALL/share/aclocal

# Overridable number of build processors
if [ "$NUM_PROCS" == "" ]; then
    NUM_PROCS=$(nproc --all)
fi

function build_3rdparty_autogen {
    echo "Building: $1"
    cd $SRC_PATH
    cd $1
    if [ -f ./autogen.sh ]; then
        env PKG_CONFIG_PATH=$PKG_CONFIG_PATH ACLOCAL_PATH=$ACLOCAL_PATH ./autogen.sh --prefix=$INSTALL $2
    fi
    if [ -f ./configure ]; then
        env PKG_CONFIG_PATH=$PKG_CONFIG_PATH ACLOCAL_PATH=$ACLOCAL_PATH ./configure --prefix=$INSTALL $2
    fi
    make clean
    make VERBOSE=1 -j$NUM_PROCS $3
}

function build_cmake {
    if [ "$CLEAN" == "1" ]; then
        if [ -d build ]; then
            rm -rf build
        fi
    fi
    if [ ! -d build ]; then
        mkdir build
    fi
    cd build
    env PKG_CONFIG_PATH=$PKG_CONFIG_PATH LDFLAGS="-L$INSTALL/lib" \
        cmake .. \
        -DCMAKE_INSTALL_PREFIX=$INSTALL \
        -DCMAKE_MODULE_PATH=$INSTALL \
        -DCMAKE_CXX_FLAGS="-isystem $INSTALL/include -L$INSTALL/lib -Wno-deprecated-declarations -Wl,-rpath-link,$INSTALL/lib" \
        -DCMAKE_C_FLAGS="-isystem $INSTALL/include -L$INSTALL/lib -Wno-deprecated-declarations -Wl,-rpath-link,$INSTALL/lib" \
        -DCMAKE_LD_FLAGS="-L$INSTALL/lib" \
        -DCMAKE_LIBRARY_PATH=$INSTALL/lib $@
    make VERBOSE=1 -j$NUM_PROCS
    if [ -f /usr/bin/sudo ]; then
        sudo make install
    else
        make install
    fi
}

function build_project {
    echo "Building project"
    cd $SRC_PATH
    cd $1
    build_cmake
}

# Clean *all* the things
if [ -d $SRC_DIR/game/Ports/Quake2/Output/Targets ]; then
    rm -rf $SRC_DIR/game/Ports/Quake2/Output/Targets
fi

# Build SDL
if [ ! -f "$INSTALL/.SDL_built" ]; then
    build_3rdparty_autogen game/SDL2 \
        "--disable-video-x11 --enable-video-wayland --enable-wayland-shared \
        --enable-video-mir --disable-mir-shared \
        --enable-video-opengles  --disable-video-opengl --disable-video-vulkan \
        --disable-alsa-shared --disable-pulseaudio-shared \
        --enable-pulseaudio --enable-hidapi --enable-libudev --enable-dbus --disable-static" ""
    make install
    touch $INSTALL/.SDL_built
fi

# Build game
if [ ! -f "$INSTALL/.game_built" ]; then
    export CFLAGS="-I/usr/lib/$MULTIARCH/dbus-1.0/include -I$INSTALL/include -DRESC='\"/opt/click.ubuntu.com/quake2touch.fredldotme/current/res/\"'"
    export CXXFLAGS="-I/usr/lib/$MULTIARCH/dbus-1.0/include -I$INSTALL/include -DRESC='\"/opt/click.ubuntu.com/quake2touch.fredldotme/current/res/\"'"
    export LIBRARY_PATH="$INSTALL/lib:/usr/lib/$MULTIARCH/"
    build_3rdparty_autogen game/Ports/Quake2/Premake/Build-SailfishOS/gmake "" "config=release sailfish_arch=$SFOS_ARCH sailfish_fbo=yes quake2-game"
    cp -a $SFOS_BIN_GAME $INSTALL/
    touch $INSTALL/.game_built
    unset CFLAGS
    unset CXXFLAGS
    unset LIBRARY_PATH
fi

# Build engine
if [ ! -f "$INSTALL/.engine_built" ]; then
    export CFLAGS="-I/usr/lib/$MULTIARCH/dbus-1.0/include -I$INSTALL/include -DRESC='\"/opt/click.ubuntu.com/quake2touch.fredldotme/current/res/\"'"
    export CXXFLAGS="-I/usr/lib/$MULTIARCH/dbus-1.0/include -I$INSTALL/include -DRESC='\"/opt/click.ubuntu.com/quake2touch.fredldotme/current/res/\"'"
    export LIBRARY_PATH="$INSTALL/lib:/usr/lib/$MULTIARCH/"
    build_3rdparty_autogen game/Ports/Quake2/Premake/Build-SailfishOS/gmake "" "config=debug sailfish_arch=$SFOS_ARCH sailfish_fbo=yes quake2-gles2"
    cp -a $SFOS_BIN_ENGINE $INSTALL/bin
    touch $INSTALL/.engine_built
    unset CFLAGS
    unset CXXFLAGS
    unset LIBRARY_PATH
fi

# Copy resources
cp -a $SRC_DIR/game/Engine/Sources/Compatibility/SDL/res $INSTALL/

# Build main sources
build_project launcher
