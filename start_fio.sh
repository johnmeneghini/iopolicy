#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

if [ $# -lt 5 -o $# -gt 5 ]; then
	echo "usage: $0 <disk> <block_size> <runtime> <numjobs> <iodepth>"
	echo " e.g.: $0 nvme16n1 64k 18800 128 64"
	echo " e.g.: $0 nvme5n2 1024k 28800 64 127"
	exit 1
fi

# echo "$1 $2 $3 $4"

disk="$1"
BS="$2"
runtime="$3"
numjobs="$4"
iodepth="$5"

if ! [ -b /dev/$disk ]; then
  echo "/dev/$disk File does not exist."
  exit 1
fi

echo "" > system.cfg
uname -av >> system.cfg
echo "" > system.cfg
nvme list-subsys >> system.cfg
echo "" > system.cfg
lscpu >> system.cfg
echo "" > system.cfg

echo "fio ioengine=libaio direct=1 rw=randrw bs=${BS} rwmixread=50 iodepth=${iodepth} numjobs=${numjobs}" > fio.txt
echo "fio --filename=/dev/${disk} --ioengine=libaio --direct=1 --size=200G --rw=randrw --refill_buffers --norandommap --randrepeat=0 --bs=${BS} --rwmixread=50 --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_read_write_test --output=/dev/null"
echo ""

fio --filename=/dev/${disk} --ioengine=libaio --direct=1 --size=400G --rw=randrw --refill_buffers --norandommap --randrepeat=0 --bs=${BS} --rwmixread=50 --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_read_write_test --output=/dev/null

