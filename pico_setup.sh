#!/bin/bash

# Exit on error
set -e

if [[ $MSYSTEM == "UCRT64" ]]; then
    echo "Running on MSYS2 UCRT64"
fi

echo "#### pico install run" >> ~/.bashrc

SKIP_PACMAN=1

# Number of cores when running make
JNUM=4

# Where will the output go?
OUTDIR="$(pwd)/pico"

# Install dependencies

OPENOCD_TAG="sdk-2.2.0"


echo "Creating $OUTDIR"
# Create pico directory to put everything in
mkdir -p $OUTDIR
cd $OUTDIR

# Clone sw repos
GITHUB_PREFIX="https://github.com/raspberrypi/"
GITHUB_SUFFIX=".git"
SDK_BRANCH="master"

for REPO in sdk examples extras playground
do
    DEST="$OUTDIR/pico-$REPO"

    if [ -d $DEST ]; then
        echo "$DEST already exists so skipping"
    else
        REPO_URL="${GITHUB_PREFIX}pico-${REPO}${GITHUB_SUFFIX}"
        echo "Cloning $REPO_URL"
        git clone -b $SDK_BRANCH $REPO_URL

        # Any submodules
        cd $DEST
        git submodule update --init
        cd $OUTDIR

        # Define PICO_SDK_PATH in ~/.bashrc
        VARNAME="PICO_${REPO^^}_PATH"
        echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$DEST" >> ~/.bashrc
        export ${VARNAME}=$DEST
    fi
done

cd $OUTDIR

# Pick up new variables we just defined
source ~/.bashrc

# Debugprobe and picotool
for REPO in picotool debugprobe
do
    DEST="$OUTDIR/$REPO"
    REPO_URL="${GITHUB_PREFIX}${REPO}${GITHUB_SUFFIX}"
    echo "<<<<<<<<<<<< $REPO Compile Start"
    if [[ "$REPO" == "picotool" ]]; then
      git clone -b $SDK_BRANCH $REPO_URL
    else
      git clone $REPO_URL
    fi

    # Build both
    cd $DEST
    git submodule update --init
    if [[ "$REPO" == "picotool" ]]; then
	if [[ "$SKIP_PACMAN" == 1 ]]; then
	    echo "Skipping pacman install checks"
	else
	    pacman -S --noconfirm $MINGW_PACKAGE_PREFIX-{toolchain,cmake,libusb}
        fi
	PICOTOOL_BIN="$OUTDIR/picotool_bin"
	mkdir $PICOTOOL_BIN
	mkdir build
	cd build
	cmake .. -DCMAKE_INSTALL_PREFIX=$PICOTOOL_BIN 
	echo "Installing picotool"
	cmake --build .
	#cp picotool.exe ${PICOTOOL_BIN}
        VARNAME="PICOTOOL_FETCH_FROM_GIT_PATH"
	echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$PICOTOOL_BIN" >> ~/.bashrc
        export ${VARNAME}=$PICOTOOL_BIN
	source ~/.bashrc
    elif [[ "$REPO" == "debugprobe" ]]; then
	cmake -S . -B build -GNinja
	cmake --build build
    fi
    echo ">>>>>>>>>> $REPO Compile Done"
    cd $OUTDIR
done

# Build blink and hello world for default boards
cd pico-examples
for board in pico pico_w pico2 pico2_w
do
    build_dir=build_$board
    cmake -S . -B $build_dir -GNinja -DPICO_BOARD=$board -DCMAKE_BUILD_TYPE=Debug -DPICOTOOL_dir=${PICOTOOL_dir}
    examples="blink hello_serial hello_usb"
    echo "Building $examples for $board"
    cmake --build $build_dir --target $examples
done

cd $OUTDIR

if [ -d openocd ]; then
    echo "openocd already exists so skipping"
    SKIP_OPENOCD=1
fi

if [[ "$SKIP_OPENOCD" == 1 ]]; then
    echo "Won't build OpenOCD"
else
    # Build OpenOCD
    echo "Building OpenOCD"
    cd $OUTDIR
    OPENOCD_CONFIGURE_ARGS="--enable-ftdi --enable-sysfsgpio --enable-bcm2835gpio --disable-werror --enable-linuxgpiod --enable-internal-jimtcl"

    git clone "${GITHUB_PREFIX}openocd${GITHUB_SUFFIX}" -b ${OPENOCD_TAG} --depth=1
    cd openocd
    ./bootstrap
    ./configure $OPENOCD_CONFIGURE_ARGS
    make -j$JNUM
    sudo make install
fi


