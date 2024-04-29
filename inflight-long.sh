#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

if [ $# -lt 1 -o $# -gt 3 ]; then
	echo "usage: $0 <nvme_ctrl> <ns> <count>"
	echo " e.g.: $0 nvme16 n2 1800"
	echo " e.g.: $0 nvme5 n1 2800"
	exit 1
fi

ctrl="$1"
ns="$2"
count="$3"

if ! [ -b /dev/${ctrl}${ns} ]; then
  echo "/dev/${ctrl}${ns} File does not exist."
  exit 1
fi

for i in `seq 1 $count`
do
    cat /proc/diskstats | fgrep ${ctrl} | fgrep ${ns}
    sleep 1
done
