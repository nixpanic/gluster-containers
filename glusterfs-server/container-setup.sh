#!/bin/bash

###
# Description: Script to move the glusterfs initial setup to bind mounted directories of Atomic Host.
# Copyright (c) 2016 Red Hat, Inc. <http://www.redhat.com>
#
# This file is part of GlusterFS.
#
# This file is licensed to you under your choice of the GNU Lesser
# General Public License, version 3 or any later version (LGPLv3 or
# later), or the GNU General Public License, version 2 (GPLv2), in all
# cases as published by the Free Software Foundation.
###

# Note: environment variables might need to listed in the systemd .service as
# well, see PassEnvironment in gluster-setup.service and 'man systemd.exec'.
#
# Set the USE_FAKE_DISK environment variable in the container deployment
#USE_FAKE_DISK=1
# You should also have a bind-mount for /srv in case data is expected to stay
# available after restarting the glusterfs-server container.
FAKE_DISK_FILE=${FAKE_DISK_FILE:-/srv/fake-disk.img}
FAKE_DISK_SIZE=${FAKE_DISK_SIZE:-10G}
FAKE_DISK_DEV=${FAKE_DISK_DEV:/dev/fake}

# Create the FAKE_DISK_FILE with fallocate, but only do so if it does not exist
# yet.
create_fake_disk_file () {
	[ -e ${FAKE_DISK_FILE} ] && return 0
	truncate --size ${FAKE_DISK_SIZE} ${FAKE_DISK_FILE}
}

# Setup a loop device for the FAKE_DISK_FILE, and create a symlink to /dev/fake
# so that it has a stable name and can be used by other components (/dev/loop*
# is numbered based on other existing loop devices).
setup_fake_disk () {
	local fakedev

	fakedev=$(losetup --find --show ${FAKE_DISK_FILE})
	[ -e "${fakedev}" ] && ln -s ${fakedev} ${FAKE_DISK_DEV}
}

main () {
  GLUSTERFS_CONF_DIR="/etc/glusterfs"
  GLUSTERFS_LOG_DIR="/var/log/glusterfs"
  GLUSTERFS_META_DIR="/var/lib/glusterd"
  GLUSTERFS_LOG_CONT_DIR="/var/log/glusterfs/container"
  GLUSTERFS_CUSTOM_FSTAB="/var/lib/heketi/fstab"

  mkdir $GLUSTERFS_LOG_CONT_DIR
  for i in $GLUSTERFS_CONF_DIR $GLUSTERFS_LOG_DIR $GLUSTERFS_META_DIR
  do
    if test "$(ls $i)"
    then
          echo "$i is not empty"
    else
          bkp=$i"_bkp"
          cp -r $bkp/* $i
          if [ $? -eq 1 ]
          then
                echo "Failed to copy $i"
                exit 1
          fi
          ls -R $i > ${GLUSTERFS_LOG_CONT_DIR}/${i}_ls
    fi
  done

  if test "$(ls $GLUSTERFS_LOG_CONT_DIR)"
  then
            echo "" > $GLUSTERFS_LOG_CONT_DIR/brickattr
            echo "" > $GLUSTERFS_LOG_CONT_DIR/failed_bricks
            echo "" > $GLUSTERFS_LOG_CONT_DIR/lvscan
            echo "" > $GLUSTERFS_LOG_CONT_DIR/mountfstab
  else
        mkdir $GLUSTERFS_LOG_CONT_DIR
        echo "" > $GLUSTERFS_LOG_CONT_DIR/brickattr
        echo "" > $GLUSTERFS_LOG_CONT_DIR/failed_bricks
  fi
  if test "$(ls $GLUSTERFS_CUSTOM_FSTAB)"
  then
        sleep 5
        pvscan > $GLUSTERFS_LOG_CONT_DIR/pvscan
        vgscan > $GLUSTERFS_LOG_CONT_DIR/vgscan
        lvscan > $GLUSTERFS_LOG_CONT_DIR/lvscan
        mount -a --fstab $GLUSTERFS_CUSTOM_FSTAB > $GLUSTERFS_LOG_CONT_DIR/mountfstab
        if [ $? -eq 1 ]
        then
              echo "mount binary not failed" >> $GLUSTERFS_LOG_CONT_DIR/mountfstab
              exit 1
        fi
        echo "Mount command Successful" >> $GLUSTERFS_LOG_CONT_DIR/mountfstab
        sleep 40
        cut -f 2 -d " " $GLUSTERFS_CUSTOM_FSTAB | while read -r line
        do
              if grep -qs "$line" /proc/mounts; then
                   echo "$line mounted." >> $GLUSTERFS_LOG_CONT_DIR/mountfstab
                   if test "ls $line/brick"
                   then
                         echo "$line/brick is present" >> $GLUSTERFS_LOG_CONT_DIR/mountfstab
                         getfattr -d -m . -e hex "$line"/brick >> $GLUSTERFS_LOG_CONT_DIR/brickattr
                   else
                         echo "$line/brick is not present" >> $GLUSTERFS_LOG_CONT_DIR/mountfstab
                         sleep 1
                   fi
              else
		   grep "$line" $GLUSTERFS_CUSTOM_FSTAB >> $GLUSTERFS_LOG_CONT_DIR/failed_bricks
                   echo "$line not mounted." >> $GLUSTERFS_LOG_CONT_DIR/mountfstab
                   sleep 0.5
             fi
        done
        if [ "$(wc -l $GLUSTERFS_LOG_CONT_DIR/failed_bricks )" -gt 1 ]
        then
              vgscan --mknodes > $GLUSTERFS_LOG_CONT_DIR/vgscan_mknodes
              sleep 10
              mount -a --fstab $GLUSTERFS_LOG_CONT_DIR/failed_bricks
        fi
  else
        echo "heketi-fstab not found"
  fi

  echo "Script Ran Successfully"
  exit 0
}

if [ -n "${USE_FAKE_DISK}" ]
then
	if ! create_fake_disk_file
	then
		echo "failed to create a fake disk at ${FAKE_DISK_FILE}"
		exit 1
	fi

	if ! setup_fake_disk
	then
		echo "failed to setup loopback device for ${FAKE_DISK_FILE}"
		exit 1
	fi
fi

main
