#!/bin/bash

# Exit on error
set -e

if [[ $MSYSTEM == "UCRT64" ]]; then
    echo "Running on MSYS2 UCRT64"
fi

echo "#### pico install run" >> ~/.bashrc
#SKIP_ARM_TOOLCHAIN=1
#SKIP_RISCV_TOOLCHAIN=1
SKIP_PACMAN=1
#SKIP_EXAMPLES=1
#SKIP_PICOTOOL=1
#SKIP_DEBUGPROBE=1

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

TOOLCHAINS="${OUTDIR}/toolchains"
mkdir -p "$TOOLCHAINS"

if [[ "${SKIP_ARM_TOOLCHAIN}" == 1 ]]; then
    echo "Skpping arm toolchain"
else
    cd "$TOOLCHAINS"
    CHAIN="arm-chain"
    mkdir "$CHAIN"
    cd $CHAIN
    mkdir "tmp"
    cd "tmp"
    ARMURL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-mingw-w64-i686-arm-none-eabi.zip"
 
    curl  -L "${ARMURL}" > ./chain.zip
    unzip -qq -d "../" "./chain.zip"
    cd ..
    rm -rf "tmp"


    PICO_ARM_TOOLCHAIN_PATH="${TOOLCHAINS}/${CHAIN}"
    VARNAME="PICO_ARM_TOOLCHAIN_PATH"
    echo "Adding $VARNAME to ~/.bashrc"
    echo "export $VARNAME=$PICO_ARM_TOOLCHAIN_PATH" >> ~/.bashrc
    export ${VARNAME}=$PICO_ARM_TOOLCHAIN_PATH

    PICO_TOOLCHAIN_PATH="${TOOLCHAINS}/${CHAIN}"
    VARNAME="PICO_TOOLCHAIN_PATH"
    echo "Adding $VARNAME to ~/.bashrc"
    echo "export $VARNAME=$PICO_TOOLCHAIN_PATH" >> ~/.bashrc
    export ${VARNAME}=$PICO_TOOLCHAIN_PATH
fi

#### RISV
if [[ "${SKIP_RISCV_TOOLCHAIN}" == 1 ]]; then
       echo "Skipping riscv toolchain"
    else
	cd $OUTDIR
	cd $TOOLCHAINS


	CHAIN="risv-chain"
	mkdir "$CHAIN"
	cd $CHAIN
	mkdir "tmp"
	cd "tmp"

        RISCVURL="https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.2.0-3/riscv-toolchain-15-x64-win.zip"
	curl  -L "${RISCVURL}" > ./chain.zip
	unzip -qq -d "../" "./chain.zip"
	cd ..
	rm -rf "tmp"
	# Define PICO_RISCV_TOOLCHAIN_PATH in ~/.bashrc
	PICO_RISCV_TOOLCHAIN_PATH="${TOOLCHAINS}/${CHAIN}"
        VARNAME="PICO_RISCV_TOOLCHAIN_PATH"
        echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$PICO_RISCV_TOOLCHAIN_PATH" >> ~/.bashrc
        export ${VARNAME}=$PICO_RISCV_TOOLCHAIN_PATH
fi



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

	PIOASM_BINARY="${DEST}/build/pioasm/pioasm.exe"
        VARNAME="PIOASM_BINARY"
        echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$PIOASM_BINARY" >> ~/.bashrc
        export ${VARNAME}=$PIOASM_BINARY
    
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
