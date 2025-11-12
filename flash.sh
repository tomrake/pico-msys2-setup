#+ /bin/bash
# Documentation:
# I assume  the device attached to the debug probe is a rp2350 device.
# The elf file passed in the first  parameter is loaded to that device using openocd.
if [ -f "$1" ]; then

"${OPENOCD_BINARY}" -f interface/cmsis-dap.cfg -f target/rp2350.cfg -c "adapter speed 5000" -c "program $1 verify reset exit"

else
    echo "$1 not found"
fi
