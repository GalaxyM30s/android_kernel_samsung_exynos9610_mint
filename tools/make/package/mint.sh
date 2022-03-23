# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
supported.patchlevels=2021-04 - 
'; } # end properties

# shell variables
block=auto;
dtbblock=/dev/block/platform/13520000.ufs/by-name/dtb;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=0;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;

# TenSeventySeven 2021 - Enable Pageboost and RAM Plus
AK_FOLDER=/tmp/anykernel
mount /system/
mount /system_root/
mount /vendor/
mount -o rw,remount -t auto /system > /dev/null
mount -o rw,remount -t auto /vendor > /dev/null

fresh=$(file_getprop "/system_root/system/system_ext/fresh.prop" "ro.fresh.maintainer")
oneui=$(file_getprop "/system_root/system/build.prop" "ro.build.PDA")

# Accomodate Exynos9611 devices' init.hardware.rc
if [ -f "/vendor/etc/init/init.exynos9611.rc" ]; then
	VENDOR_INIT_RC=/vendor/etc/init/init.exynos9611.rc
else
	VENDOR_INIT_RC=/vendor/etc/init/init.exynos9610.rc
fi

if [ ! -z $oneui ]; then
	if [ -z $fresh ]; then
		ui_print "  - One UI detected!"
		ui_print "    - Enabling Pageboost"
		patch_prop /vendor/build.prop 'ro.config.pageboost.vramdisk.minimize' "true"
		patch_prop /vendor/build.prop 'ro.config.pageboost.active_launch.enabled' "true"
		patch_prop /vendor/build.prop 'ro.config.pageboost.io_prefetch.enabled' "true"
		patch_prop /vendor/build.prop 'ro.config.pageboost.io_prefetch.level' "3"

		cp -rf $AK_FOLDER/files_oneui/system/etc/init/init.mint.rc /system/etc/init/init.mint.rc
		cp -rf $AK_FOLDER/files_oneui/system/etc/init/init.mint.rc /system_root/system/etc/init/init.mint.rc
		cp -rf $AK_FOLDER/files_oneui/vendor/etc/fstab.sqzr /vendor/etc/fstab.sqzr

		chmod 644 /system/etc/init/init.mint.rc
		chmod 644 /system_root/system/etc/init/init.mint.rc
		chmod 644 /vendor/etc/fstab.sqzr

		# Disable SSWAP for RAM Plus and Pageboost
		remove_section ${VENDOR_INIT_RC} 'service swapon /system/bin/sswap -s -z -f 2048' 'oneshot'
		replace_string ${VENDOR_INIT_RC} 'swapon_all /vendor/etc/fstab.dummy' 'swapon_all /vendor/etc/fstab.exynos9610' 'swapon_all /vendor/etc/fstab.sqzr' global
		replace_string ${VENDOR_INIT_RC} 'swapon_all /vendor/etc/fstab.dummy' 'swapon_all /vendor/etc/fstab.model' 'swapon_all /vendor/etc/fstab.sqzr' global
		replace_string ${VENDOR_INIT_RC} 'swapon_all /vendor/etc/fstab.dummy' 'swapon_all /vendor/etc/fstab.zram' 'swapon_all /vendor/etc/fstab.sqzr' global
		append_file ${VENDOR_INIT_RC} 'swapon_all /vendor/etc/fstab.sqzr' init.ramplus.rc
		append_file ${VENDOR_INIT_RC} 'start pageboostd' init.pageboost.rc
	else
		ui_print "  - FreshROMs detected! RAM Plus is already enabled!"
	fi
else
	ui_print "  - AOSP ROM detected!"

	mkdir -p /vendor/overlay
	rm -rf /vendor/overlay/MintZramWb.apk
fi

umount /system
umount /system_root
umount /vendor

## AnyKernel boot install
split_boot;

flash_boot;

# Flash dtb
ui_print "  - Installing Exynos device tree blob (DTB)...";
flash_generic dtb;
## end boot install
