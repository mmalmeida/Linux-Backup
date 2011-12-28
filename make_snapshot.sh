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

CHMOD=/bin/chmod;
MOUNT=/bin/mount;
UMOUNT=/bin/umount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;

RSYNC=/usr/bin/rsync;


# ------------- file locations -----------------------------------------

#Machines needs to be on hosts file of the host
MACHINES=(webservices)
CONFIG_LOCATION=/home/malmeida/git/Linux-Backup/
SNAPSHOT_RW=/mnt/machine
BASE_LOCATION=/mnt/machine/
MOUNT_DEVICE=192.168.10.100:/mnt/hdc/snapshots/
# ------------- the script itself --------------------------------------


snapshot_machine(){

	# make sure we're running as root
	if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

	# attempt to remount the RW mount point as RW; else abort
	## XXX - No nosso caso, sera um chmod provavel...
	#$MOUNT -o remount,rw $MOUNT_DEVICE $SNAPSHOT_RW ;

	if [ "$MACHINE" != "localhost" ] ; then
#		$MOUNT -t nfs -o ro $MOUNT_DEVICE $SNAPSHOT_RW
		$MOUNT -o remount,rw,nfsvers=3 $MOUNT_DEVICE $SNAPSHOT_RW ;
		if (( $? )); then
		{
			$ECHO "snapshot: could not mount $MOUNT_DEVICE";
			exit;
		}
		fi;
	else
		BASE_LOCATION=/;
	fi;


	# rotating snapshots of $MACHINE (fixme: this should be more general)

	# step 1: delete the oldest snapshot, if it exists:
	if [ -d $SNAPSHOT_RW/$MACHINE/daily.3 ] ; then			\
	$RM -rf $SNAPSHOT_RW/$MACHINE/daily.3 ;				\
	fi ;

	# step 2: shift the middle snapshots(s) back by one, if they exist
	if [ -d $SNAPSHOT_RW/$MACHINE/daily.2 ] ; then			\
	$MV $SNAPSHOT_RW/$MACHINE/daily.2 $SNAPSHOT_RW/$MACHINE/daily.3 ;	\
	fi;
	if [ -d $SNAPSHOT_RW/$MACHINE/daily.1 ] ; then			\
	$MV $SNAPSHOT_RW/$MACHINE/daily.1 $SNAPSHOT_RW/$MACHINE/daily.2 ;	\
	fi;

	# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
	# if that exists
	if [ -d $SNAPSHOT_RW/$MACHINE/daily.0 ] ; then			\
	$CP -al $SNAPSHOT_RW/$MACHINE/daily.0 $SNAPSHOT_RW/$MACHINE/daily.1 ;	\
	fi;

	# step 4: rsync from the system into the latest snapshot (notice that
	# rsync behaves like cp --remove-destination by default, so the destination
	# is unlinked first.  If it were not so, this would copy over the other
	# snapshot(s) too!
	$RSYNC								\
		-ave ssh --delete --delete-excluded				\
		--exclude-from="$EXCLUDES"				\
		--include-from="$INCLUDES"				\
		/ $SNAPSHOT_RW/$MACHINE/daily.0/ ;

	# step 5: update the mtime of daily.0 to reflect the snapshot time
	$TOUCH $SNAPSHOT_RW/$MACHINE/daily.0 ;

	# and thats it for $MACHINE.

	# now remount the RW snapshot mountpoint as readonly
	#$MOUNT -o remount,ro $MOUNT_DEVICE $SNAPSHOT_RW ;
	if [ "$MACHINE" != "localhost" ] ; then
#		$UMOUNT "$BASE_LOCATION";
		$MOUNT -o remount,ro,nfsvers=3 $MOUNT_DEVICE $SNAPSHOT_RW ;
		if (( $? )); then
		{
			$ECHO "snapshot: could not unmount $BASE_LOCATION";
			exit;
		} fi;
	fi;
}


#$CHMOD -R 750 $SNAPSHOT_RW ;
for i in ${MACHINES[@]}; do

	MACHINE=${i};
	EXCLUDES=$CONFIG_LOCATION$MACHINE"_exclude";
	INCLUDES=$CONFIG_LOCATION$MACHINE"_include";
	snapshot_machine;
done
#$CHMOD -R 550 $SNAPSHOT_RW ;
