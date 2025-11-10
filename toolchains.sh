#!/bin/bash

# Exit on error
set -e


OUTDIR="$(pwd)/pico"

mkdir -p $OUTDIR
cd $OUTDIR

REPO="toolchains"
mkdir "$REPO"
cd "$REPO"
CHAIN="arm-chain"
mkdir "$CHAIN"
cd $CHAIN
mkdir "tmp"
cd "tmp"


ENDINGS={zip,zip.asc,zip.sha256asc}
URLFRONT="https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/"
URLFRONT="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/14.3.rel1/binrel/"
FILEFRONT="arm-gnu-toolchain-14.3.rel1-mingw-w64-x86_64-arm-none-eabi."

for ext in "zip" "zip.asc" "zip.sha256asc"
do 
  # echo $ext
   f="${FILEFRONT}${ext}"
   u="${URLFRONT}${f}"
   curl  $u > $f
done
# Check sha256
sha256sum -c "./${FILEFRONT}zip.sha256asc"
# Unpack in CHAIN directory
unzip -qq -d "../" "./${FILEFRONT}zip"
cd ..
rm -rf "tmp"
