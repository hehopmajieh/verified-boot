# OLinuXino-A20 Signed U-Boot 

1. Getting u-boot source

```bash
$ mkdir ~/olinuxino
$ cd ~/olinuxino
$ git clone git://git.denx.de/u-boot.git
$ cd u-boot
$ git checkout v2019.01
$ cd ..
```

2. Get toolchain (tested with gcc-linaro 7.2.1, 7.4.1)

```bash
$ wget https://releases.linaro.org/components/toolchain/binaries/7.4-2019.02/arm-linux-gnueabihf/gcc-linaro-7.4.1-2019.02-x86_64_arm-linux-gnueabihf.tar.xz
$ tar -xvf gcc-linaro-7.4.1-2019.02-x86_64_arm-linux-gnueabihf.tar.xz
$ export PATH=$PATH:/path/to/gcc-linaro-7.4.1_toolchain/bin
```

3. Build u-boot
```bash
$ cd u-boot
$ make CROSS_COMPILE=arm-linux-gnueabihf- <board_name>_defconfig
$ make CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
```

From menu  <u> Boot images </u> : 
    [ enable CONFIG_FIT, CONFIG_FIT_SIGNATURE and CONFIG_FIT_VERBOSE ]

Build u-boot:
```bash
$ make CROSS_COMPILE=arm-linux-gnueabihf- -j4
```
Generate RSA keys to sign u-boot
```bash
$ mkdir keys
$ openssl genpkey -algorithm RSA -out keys/dev.key -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:65537
# Create a certificate containing public key 
$ openssl req -batch -new -x509 -key keys/dev.key -out keys/dev.crt
```
U-boot FIT configuration :
Create file containig FIT config in u-boot directory and name it kernel_fdt.its:

```fdt
/dts-v1/;

/ {

    description = "FIT image with single Linux kernel, FDT blob";

    #address-cells = <1>;


    images {

        kernel@0 {

            description = "ARM Linux kernel";

            data = /incbin/("./zImage"); 

            type = "kernel";

            arch = "arm";

            os = "linux";

            compression = "none";

            load = <0x40008000>;

            entry = <0x40008000>;

            hash@1 {

                algo = "sha256";

            };

        };

 	ramdisk@0 {
                    description = "initramfs";
                    data = /incbin/("initramfs.cpio.gz");
                    type = "ramdisk";
                    arch = "arm";
                    os = "linux";
                    compression = "gzip";
            };
	

        fdt@0 {

            description = "Olimex SOM204 Devicetree blob";

            data = /incbin/("./sun7i-a20-olimex-som204-evb-emmc.dtb");

            type = "flat_dt";

            arch = "arm";

            compression = "none";

            hash@1 {

                algo = "sha256";

            };

        };

    };


    configurations {

        default = "conf@0";


        conf@0 {

            description = "Boot Linux kernel, FDT blob";

            kernel = "kernel@0";
	
	    ramdisk = "ramdisk@0";		

            fdt = "fdt@0";
	    


            signature@0 {

                algo = "sha256,rsa2048";

                key-name-hint = "dev";

                sign-images = "kernel", "fdt";

            };

        };

    };

};

```
In this example we build signed image for Olimex SOM204 Board, containign compressed kerenl image (zImage) and initramfs build using Buildroot.
To build kernek image refer to official Mainline kernel how-to.
Buildroot source can be obtained from official buildroot repo.
Example kernel image and  Buildroot defconfig can be found in this repo.

```bash
$ cp ../linux-mainline/arch/arm/boot/zImage .
$ cp ../linux-mainline/arch/arm/boot/dts/device_tree_blob.dtb .
$ cp ../initramfs/initramfs.cpio.gz . 
# If you use different initramfs compression metod, you must edit kenrel config to support it
# Build FIT Image
$ tools/mkimage -f kernel_fdt.its -k keys -K dts/dt.dtb -r -F fitImage
# After updating dt.dtb in previus step we must rebuild u-boot
$ tools/mkimage -f kernel_fdt.its -k keys -K dts/dt.dtb -r -F fitImage

```

4. Prepare SD Card
We need at least one partition to load u-boot FIT Image:
```bash
$ export card = /dev/sdX # where sdX or mmcblkX is your card
$ blockdev --rereadpt ${card}
$ cat <<EOT | sfdisk ${card}
1M,32M,c
,,L
EOT
```
This will create 32MB boot partition starting at 1MB and the rest as as one partition
```bash
$ mkfs.ext4 /dev/sdX 
# Write u-boot to SD Card :
$ dd if=u-boot-sunxi-with-spl.bin of=/dev/sdX bs=1024 seek=8
$ mount /dev/sdX /mnt #or directory of your choice
$ cp fitImage /mnt/.
```
Create u-boot boot script :
```bash
$ cat << EOF > boot.cmd
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait panic=10 
load mmc 0:1 0x60000000 fitImage
bootm 0x60000000
EOF
$ mkimage -C none -A arm -T script -d boot.cmd boot.scr
$ cp boot.scr /mnt/.
$ umount /mnt
```


