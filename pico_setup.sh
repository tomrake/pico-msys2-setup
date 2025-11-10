#!/bin/bash

# Exit on error
set -e

if [[ $MSYSTEM == "UCRT64" ]]; then
    echo "Running on MSYS2 UCRT64"
fi

echo "#### pico install run" >> ~/.bashrc

SKIP_PACMAN=1
SKIP_EXAMPLES=1
SKIP_PICOTOOL=1
SKIP_DEBUGPROBE=1

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

# picotool
if [[ "$SKIP_PICOTOOL" == 1 ]]; then
    echo "Skipping picotool"
else
    REPO="picotool"
    DEST="$OUTDIR/$REPO"
    REPO_URL="${GITHUB_PREFIX}${REPO}${GITHUB_SUFFIX}"
    echo "<<<<<<<<<<<< $REPO Compile Start"
    git clone -b $SDK_BRANCH $REPO_URL
    cd $DEST
    git submodule update --init

    if [[  -n ${PICOTOOL_BINARY} && -x ${PICOTOOL_BINARY} ]]; then
	echo "picotool found at ${PICOTOOL_BINARY} Not building again"
    else
	echo "Building picotool"
	PICOTOOL_GIT_ARTIFACT="$OUTDIR/picotool_bin"
	PICOTOOL_BINARY="$PICOTOOL_GIT_ARTIFACT/picotool/picotool.exe"
	mkdir $PICOTOOL_GIT_ARTIFACT
	
	if [[ "$SKIP_PACMAN" == 1 ]]; then
	    echo "Skipping pacman install checks"
	else
	    pacman -S --noconfirm $MINGW_PACKAGE_PREFIX-{toolchain,cmake,libusb}
        fi

	mkdir build
	cd build
	cmake .. -DCMAKE_INSTALL_PREFIX=$PICOTOOL_GIT_ARTIFACT 
	echo "Installing picotool"
	cmake --build .
	#cp picotool.exe ${PICOTOOL_GIT_ARTIFACT}
	# picoprobe and other depend on this directory existing.
        VARNAME="PICOTOOL_FETCH_FROM_GIT_PATH"
	echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$PICOTOOL_GIT_ARTIFACT" >> ~/.bashrc
        export ${VARNAME}=$PICOTOOL_GIT_ARTIFACT
        # This is actual product we depend on.
        VARNAME="PICOTOOL_BINARY"
	echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$PICOTOOL_BINARY" >> ~/.bashrc
        export ${VARNAME}=$PICOTOOL_BINARY
    fi
    echo ">>>>>>>>>> $REPO Compile Done"
    cd $OUTDIR
    # Pick up new variables we just defined
    source ~/.bashrc
fi

# debugprobe
if [[ "$SKIP_DEBUGPROBE" == 1 ]]; then
    echo "Skipping debugprobe"
else
    REPO="debugprobe"
    DEST="$OUTDIR/$REPO"
    REPO_URL="${GITHUB_PREFIX}${REPO}${GITHUB_SUFFIX}"
    echo "<<<<<<<<<<<< $REPO Compile Start"
    git clone $REPO_URL
    cd $DEST
    git submodule update --init
  
    cmake -S . -B build -GNinja
    cmake --build build
 
    echo ">>>>>>>>>> $REPO Compile Done"
    cd $OUTDIR
fi

    
# Build blink and hello world for default boards
if [[ "$SKIP_EXAMPLES" == 1 ]]; then
    echo "Skipping Examples"
else
    cd pico-examples
    for board in pico pico_w pico2 pico2_w
    do
	build_dir=build_$board
	cmake -S . -B $build_dir -GNinja -DPICO_BOARD=$board -DCMAKE_BUILD_TYPE=Debug -DPICOTOOL_dir=${PICOTOOL_dir}
	examples="blink hello_serial hello_usb"
	echo "Building $examples for $board"
	cmake --build $build_dir --target $examples
    done
fi
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
    OPENOCD_CONFIGURE_ARGS="--enable-ftdi  --disable-werror --enable-internal-jimtcl"

    git clone "${GITHUB_PREFIX}openocd${GITHUB_SUFFIX}" -b ${OPENOCD_TAG} --depth=1
    cd openocd
    mkdir openocd
    OPENOCD_INSTALL_DIR="$OUTDIR/openocd/openocd"
    git submodule update --init
    ./bootstrap
    ./configure --prefix="${OPENOCD_INSTALL_DIR}" $OPENOCD_CONFIGURE_ARGS
    make -j$JNUM
    make install
    OPENOCD_BINARY="$OPENOCD_INSTALL_DIR/bin/openocd.exe"
    VARNAME="OPENOCD_BINARY"
    echo "Adding $VARNAME to ~/.bashrc"
    echo "export $VARNAME=$OPENOCD_BINARY" >> ~/.bashrc
    export ${VARNAME}=$OPENOCD_BINARY
    cd $OUTDIR
fi

# Pick up new variables we just defined
source ~/.bashrc
