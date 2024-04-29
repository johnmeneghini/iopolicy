#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

# this assumes inflight-long.sh is in the same directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 3 -o $# -gt 3 ]; then
	echo "usage: $0 <output_filename> <namespace> <count>"
	echo " e.g.: $0 POWERSTORE-QD nvme16n2 1800"
	echo " e.g.: $0 A400-RR nvme5n1 2800"
	exit 1
fi

output="$1"
disk="$2"
count="$3"

if ! [ -b /dev/${disk} ]; then
  echo "/dev/${disk} File does not exist!"
  exit 1
fi

ctrl=$(echo "${disk}" | sed 's/n[0-9]*$//')
ns=$(echo "${disk}" | sed 's/^nvme[0-9]*//')
#echo "disk = $disk, ctrl = $ctrl, ns = $ns"

subsys_num=$(echo "${ctrl}" | sed 's/^nvme//')

mkdir -p cfgs

echo "Creating file cfgs/${output}.cfg"

echo -n "/sys/class/nvme-subsystem/nvme-subsys${subsys_num}/iopolicy is : " > cfgs/${output}.cfg
cat /sys/class/nvme-subsystem/nvme-subsys${subsys_num}/iopolicy >> cfgs/${output}.cfg
for filename in /sys/class/nvme-subsystem/nvme-subsys${subsys_num}/nvme*; do
	suffix=$(echo "${filename}" | sed 's/^.*nvme[0-9]*//')
	if [ -z "${suffix}" ]; then
#		echo "${filename}" >> $cfgs/{output}.cfg
		echo "----------------------------------------------------" >> cfgs/${output}.cfg
		for ctrlname in ${filename}/nvme*; do
			fns=$(echo "${ctrlname}" | sed 's/^.*nvme[0-9]*c[0-9]*//')
			if [ "${fns}" == "${ns}" ]; then
				echo -n "controller  : " >> cfgs/${output}.cfg
				echo "${ctrlname}" >> cfgs/${output}.cfg
				echo -n "ana_state   : " >> cfgs/${output}.cfg
				cat ${ctrlname}/ana_state >> cfgs/${output}.cfg
			fi
		done
#		echo -n "model       : " >> cfgs/${output}.cfg
#		cat ${filename}/model >> cfgs/${output}.cfg
		echo -n "transport   : " >> cfgs/${output}.cfg
		cat ${filename}/transport >> cfgs/${output}.cfg
		echo -n "queue_count : " >> cfgs/${output}.cfg
		cat ${filename}/queue_count >> cfgs/${output}.cfg
		echo -n "sqsize      : " >> cfgs/${output}.cfg
		cat ${filename}/sqsize >> cfgs/${output}.cfg
		echo -n "numa_node   : " >> cfgs/${output}.cfg
		cat ${filename}/numa_node >> cfgs/${output}.cfg
#	else
#		echo "skippig $filename because of suffix \"$suffix\""
	fi
done

# cat  cfgs/${output}.cfg

echo "Creating file /run/$output"

$DIR/inflight-long.sh $ctrl $ns $count > /run/${output}

echo "Done with /run/$output"

cp /run/$output .

