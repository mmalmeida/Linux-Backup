#!/bin/bash
# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots of /home whenever called
# ----------------------------------------------------------------------

unset PATH	# suggestion from H. Milz: avoid accidental use of $PATH

# ------------- system commands used by this script --------------------
ID=/usr/bin/id;
ECHO=/bin/echo;
DATE=/bin/date;
PRINTF=/usr/bin/printf;

CHMOD=/bin/chmod;
MOUNT=/bin/mount;
#MOUNT=/usr/bin/sshfs;
UMOUNT=/bin/umount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;

RSYNC=/usr/bin/rsync;


# ------------- file locations -----------------------------------------

#Machines needs to be on hosts file of the host
MACHINES=($HOSTNAME)
CONFIG_LOCATION=/etc/backup/
SNAPSHOT_RW=/mnt/machine
BASE_LOCATION=/mnt/machine/
MOUNT_DEVICE=192.168.10.100:/mnt/hdc/snapshots/
# ------------- the script itself --------------------------------------


snapshot_machine(){

	# make sure we're running as root
	if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

	# attempt to remount the RW mount point as RW; else abort
	if [ "$MACHINE" != "localhost" ] ; then
		$PRINTF '%s: Mounting device rw \n' "$($DATE '+%Y-%m-%d %H:%M')"
#		if (!($MOUNT backup@$MOUNT_DEVICE $SNAPSHOT_RW -C -o nonempty)); then
#			$ECHO "snapshot: could not mount $MOUNT_DEVICE";
#	        	exit 1
#		fi

		$MOUNT -o remount,rw,nfsvers=3 $MOUNT_DEVICE $SNAPSHOT_RW ;
		if (( $? )); then
		{
			$ECHO "snapshot: could not mount $MOUNT_DEVICE";
			exit;
		}
		fi;
	fi;
	$PRINTF '%s: Device  mounted, moving snapshots \n' "$($DATE '+%Y-%m-%d %H:%M')"

	# rotating snapshots of $MACHINE (fixme: this should be more general)

	# step 1: delete the oldest snapshot, if it exists:
	if [ -d $SNAPSHOT_RW/$MACHINE/daily.3 ] ; then			\
	$RM -rf $SNAPSHOT_RW/$MACHINE/daily.3 ;				\
	fi ;
	$PRINTF '%s: Deleted daily.3 \n' "$($DATE '+%Y-%m-%d %H:%M')"

	# step 2: shift the middle snapshots(s) back by one, if they exist
	if [ -d $SNAPSHOT_RW/$MACHINE/daily.2 ] ; then			\
	$MV $SNAPSHOT_RW/$MACHINE/daily.2 $SNAPSHOT_RW/$MACHINE/daily.3 ;	\
	fi;
	$PRINTF '%s: Pushed daily.2 to daily.3 \n' "$($DATE '+%Y-%m-%d %H:%M')"

	if [ -d $SNAPSHOT_RW/$MACHINE/daily.1 ] ; then			\
	$MV $SNAPSHOT_RW/$MACHINE/daily.1 $SNAPSHOT_RW/$MACHINE/daily.2 ;	\
	fi;
	$PRINTF '%s: Pushed daily.1 to daily.2 \n' "$($DATE '+%Y-%m-%d %H:%M')"

	# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
	# if that exists
	if [ -d $SNAPSHOT_RW/$MACHINE/daily.0 ] ; then			\
	$CP -al $SNAPSHOT_RW/$MACHINE/daily.0 $SNAPSHOT_RW/$MACHINE/daily.1 ;	\
	fi;
	$PRINTF '%s: Pushed daily.0 to daily.1 \n' "$($DATE '+%Y-%m-%d %H:%M')"

	# step 4: rsync from the system into the latest snapshot (notice that
	# rsync behaves like cp --remove-destination by default, so the destination
	# is unlinked first.  If it were not so, this would copy over the other
	# snapshot(s) too!
	$PRINTF '%s: Preparing to rsync... \n' "$($DATE '+%Y-%m-%d %H:%M')"

	$RSYNC								\
		-ae ssh --delete --delete-excluded				\
		--exclude-from="$EXCLUDES"				\
		--include-from="$INCLUDES"				\
		/ $SNAPSHOT_RW/$MACHINE/daily.0/ ;

	$PRINTF '%s: Rsync finished! \n' "$($DATE '+%Y-%m-%d %H:%M')"

	# step 5: update the mtime of daily.0 to reflect the snapshot time
	$TOUCH $SNAPSHOT_RW/$MACHINE/daily.0 ;

	# and thats it for $MACHINE.

	# now remount the RW snapshot mountpoint as readonly
	if [ "$MACHINE" != "localhost" ] ; then
		$MOUNT -o remount,ro,nfsvers=3 $MOUNT_DEVICE $SNAPSHOT_RW ;
#		fusermount -u $SNAPSHOT_RW;
		if (( $? )); then
		{
			$ECHO "snapshot: could not unmount $BASE_LOCATION";
			exit;
		} fi;
		$ECHO "Mounted device ro"
		fi;
}

for i in ${MACHINES[@]}; do

	MACHINE=${i};
	EXCLUDES=$CONFIG_LOCATION$MACHINE"_exclude";
	INCLUDES=$CONFIG_LOCATION$MACHINE"_include";
	snapshot_machine;
done
