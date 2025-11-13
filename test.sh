#! /bin/bash
set -e

if [ 
    for fn in PICO_SDK_PATH APICO_EXAMPLES_PATH PICO_EXTRAS_PATH PICO_PLAYGROUND_PATH
do
    if [[ -f "${!fn}/README.md" ]]; then
	echo "$fn is found"
    else
	echo "XXXX $fn not found!"
    fi
done &&
"${OPENOCD_BINARY}" -v &&

"${PICOTOOL_BINARY}" version &&

"${PIOASM_BINARY}" --version ];  then
   echo "All Tests Pass"
fi
