setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait panic=10
load mmc 0:1 0x60000000 fitImage
bootm 0x60000000
