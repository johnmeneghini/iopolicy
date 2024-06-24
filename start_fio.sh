#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

if [ $# -lt 6 -o $# -gt 6 ]; then
	echo "usage: $0 <disk> <test> <block_size> <runtime> <numjobs> <iodepth>"
	echo " e.g.: $0 nvme9n2 bench-fio 4k 60 \"8 16 32 64\" \"16 32 64 128\""
	echo " e.g.: $0 nvme5n2 randrw 512k 28800 64 127"
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

ENGINE="fio"
TESTARG=""
TESTARG2=""
TESTARG3="$TEST"
DISK=""
OUTPUT=""

case "$TEST" in
	"read")
		DISK=" --filename=/dev/${disk}"
		TESTARG="--rw=randread  --eta-newline=1 --readonly"
        TESTARG2=" --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null"
		;;
	"write")
		DISK=" --filename=/dev/${disk}"
		TESTARG="--rw=write"
        TESTARG2=" --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null"
		;;
	"randread")
		DISK=" --filename=/dev/${disk}"
		TESTARG="--rw=randread --refill_buffers --norandommap --randrepeat=0 --readonly"
        TESTARG2=" --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null"
		;;
	"randwrite")
		DISK=" --filename=/dev/${disk}"
		TESTARG="--rw=randwrite --refill_buffers --norandommap --randrepeat=0"
        TESTARG2=" --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null"
		;;
	"rw,randwrite")
		DISK=" --filename=/dev/${disk}"
		TESTARG="--rw=rw,randwrite --refill_buffers --norandommap --randrepeat=0"
        TESTARG2=" --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null"
		;;
	"randrw")
		DISK=" --filename=/dev/${disk}"
		TESTARG="--rw=randrw --refill_buffers --norandommap --randrepeat=0 --rwmixread=50"
        TESTARG2=" --ioengine=libaio --direct=1 --size=400G ${TESTARG} --bs=${BS} --iodepth=${iodepth} --numjobs=${numjobs} --runtime=${runtime} --group_reporting --name=${disk}_${BS}_${TEST}_test --output=/dev/null"
		;;
	"bench-fio")
		ENGINE="bench-fio"
		OUTPUT="/run/benchfio"
		DISK=" -d /dev/$disk"
		TESTARG="-m read randread write randwrite"
		TESTARG2=" -t device -o $OUTPUT  -b ${BS} --iodepth ${iodepth} --numjobs ${numjobs} --runtime ${runtime} ${TESTARG} --direct=1 --destructive"
		TESTARG3="read randread write randwrite"
		;;
	*)
		echo "Error: \"$TEST\" is invalid."
		echo "usage: $0 <disk> <read|write|randread|randwrite|rw,randwrite|randrw|bench-fio> <block_size> <runtime> <numjobs> <iodepth>"
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

echo "$ENGINE libaio direct ${TESTARG3} ${BS} iodepth ${iodepth} numjobs ${numjobs}" > fio.txt
echo "$ENGINE $DISK $TESTARG2" > fio_command.txt
cat fio_command.txt
echo ""

$ENGINE $DISK $TESTARG2

#if [ ! -z "${OUTPUT}" ]; then
#	echo "Copy $OUTPUT directory to $PWD"
#	mv ${OUTPUT} .
#fi
