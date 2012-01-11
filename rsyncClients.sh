#!/bin/bash

rsync -av webservices_* make_snapshot.sh  root@192.168.10.102:/etc/backup/
rsync -av dataservices_*  make_snapshot.sh root@192.168.10.103:/etc/backup/
rsync -av externalservices_* make_snapshot.sh root@192.168.10.104:/etc/backup/
