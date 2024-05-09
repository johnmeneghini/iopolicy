#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

if [ $# -lt 6 -o $# -gt 6 ]; then
	echo "usage: $0 <disk> <test> <block_size> <runtime> <numjobs> <iodepth>"
	echo " e.g.: $0 nvme16n1 randread 64k 18800 40 64"
	echo " e.g.: $0 nvme5n2 randrw 512k 28800 64 127"
	echo " e.g.: $0 nvme5n2 write 4k 28800 64 32"
	exit 1
fi

# echo "$1 $2 $3 $4"

disk="$1"
TEST="$2"
BS="$3"
runtime="$4"
numjobs="$5"
iodepth="$6"

if ! [ -b /dev/$disk ]; then
  echo "/dev/$disk File does not exist."
  exit 1
fi

TESTARG=""

case "$TEST" in
	"read")
		TESTARG="--rw=randread  --eta-newline=1 --readonly"
		;;
	"write")
		TESTARG="--rw=write"
		;;
	"randread")
		TESTARG="--rw=randread --refill_buffers --norandommap --randrepeat=0 --readonly"
		;;
	"randwrite")
		TESTARG="--rw=randwrite --refill_buffers --norandommap --randrepeat=0"
		;;
	"rw,randwrite")
		TESTARG="--rw=rw,randwrite --refill_buffers --norandommap --randrepeat=0"
		;;
	"randrw")
		TESTARG="--rw=randrw --refill_buffers --norandommap --randrepeat=0 --rwmixread=50"
		;;
	*)
		echo "Error: \"$TEST\" is invalid."
		echo "usage: $0 <disk> <read|write|randread|randwrite|rw,randwrite|randrw> <block_size> <runtime> <numjobs> <iodepth>"
		exit 1
		;;
esac

echo "" > system.cfg
uname -av >> system.cfg

echo "" >> system.cfg
nvme list-subsys >> system.cfg
echo "" >> system.cfg
lscpu >> system.cfg
echo "" >> system.cfg

echo "fio ioengine=libaio direct=1 rw=${TEST} bs=${BS} iodepth=${iodepth} numjobs=${numjobs}" > fio.txt
echo "fio --filename=/dev/${disk} --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null" > fio_command.txt
cat fio_command.txt
echo ""

fio --filename=/dev/${disk} --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null

