#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

# this assumes collect_inflight-data.sh is in the same directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

display_help() {
	echo ""
	echo " usage: $0 <\"iopolicy1,iopolicy2,...\"> <filename> <namespace> <count>"
	echo ""
	echo "   <\"iopolicy1,iopolicy2,...\"> string iopolicy to use"
	echo "   <filename> filename prefix to use - passed to collect_inflight_data.sh"
	echo "   <namepace> nvme device name to test"
	echo "   <count> nvme device name to test"
	echo ""
	echo "    Valid iopolicy input:"
	echo "        		\"numa\""
	echo "        		\"round-robin\""
	echo "        		\"queue-depth\""
	echo "        		\"latency\""
	echo ""
	echo "  e.g.: $0 \"round-robin,queue-depth,numa\" ARRAY1 nvme12n2 600"
	echo "  e.g.: $0 \"round-robin,numa\" ARRAY2 nvme2n1 800"
	echo ""
}

continue_step() {
    echo ""
        echo -n "Type any key to continue, e to exit: "
        read line
        case "$line" in
                e|E) echo ""
                     exit 1
        ;;
                *) echo ""
                    return 1
                ;;
        esac
}

if [ $# -lt 4 -o $# -gt 4 ]; then
	echo ""
	echo "usage: $0 <\"iopolicy1,iopolicy2,...\"> <filename> <namespace> <count>"
	echo "  e.g.: $0 \"round-robin,queue-depth,numa\" ARRAY1 nvme12n2 800"
	echo ""
	exit 1
fi

inputlist="$1"
output="$2"
disk="$3"
count="$4"

if ! [ -b /dev/${disk} ]; then
  echo "/dev/${disk} File does not exist!"
  exit 1
fi

ctrl=$(echo "${disk}" | sed 's/n[0-9]*$//')
ns=$(echo "${disk}" | sed 's/^nvme[0-9]*//')
subsys_num=$(echo "${ctrl}" | sed 's/^nvme//')

j=1
IFS=',' read -ra ADDR <<< "${inputlist}"
for policy in "${ADDR[@]}"; do
	(( j++))
	case "$policy" in
	"numa")
		;;
	"round-robin")
		;;
	"queue-depth")
		;;
	"latency")
		;;
	*)
		echo "Error: \"$policy\" is invalid."
		display_help >&2
		exit 1
		;;
	esac
done

((jcount = j * count))

echo ""
echo "Be sure to start fio in a separate shell with start_fio.sh"
echo ""
echo "     \"start_fio.sh <disk> <block_size> <runtime> <numjobs> <iodepth>\""
echo ""
echo " e.g: \"$DIR/start_fio.sh $disk 1024k $jcount 127 127\""
echo ""
echo "Monitor progress with iostat"
echo ""
echo " \"iostat -x ID \$(cat /proc/diskstats | fgrep $ctrl | fgrep $ns | awk '{print \$3}' | sort -r) 4\""

continue_step

sleep 2

mkdir -p logs

for policy in "${ADDR[@]}"; do
	dmesg -C
	sleep 5
	echo -n "nvme-subsys${subsys_num}/iopolicy is "
	cat /sys/class/nvme-subsystem/nvme-subsys${subsys_num}/iopolicy
	echo "setting iopolicy for nvme-subsys${subsys_num} to $policy "
	echo "setting iopolicy for nvme-subsys${subsys_num} to $policy " > logs/${output}-${policy}-dmesg.log
	echo "$policy" > /sys/class/nvme-subsystem/nvme-subsys${subsys_num}/iopolicy
	sleep 20
	$DIR/collect_inflight-data.sh ${output}-${policy} $disk $count
	sleep 10
	dmesg >> logs/${output}-${policy}-dmesg.log
done

