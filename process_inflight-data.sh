#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

display_full_help() {
	echo ""
	echo " usage: $0 [ -h | -n | -p <ps | jpeg | png> ] <\"filename,filename,...\">"
	echo ""
	echo "   -h                 display help"
	echo "   -n                 no namespace - exlude namespace statistics from graph"
	echo "   -p  <type>         create postscript, jpeg or png output. the default is jpeg."
	echo "   <\"filename,filename\"> string of input files generated from collect_inflight_data.sh"
	echo ""
	echo "  e.g.: $0 \"A400-RR\""
	echo "  e.g.: $0 -p ps -n \"POWERSTORE-QD,POWERSTORE-RR,POWERSTORE-NUMA\""
	echo "  e.g.: $0 -p png \"A400-NUMA\""
	echo ""
}

display_help() {
	echo ""
	echo " usage: $0 [ -h | -n | -p <ps | jpeg | png> ] <\"filename,filename,...\">"
	echo ""
	echo "  e.g.: $0 \"A400-RR\""
	echo "  e.g.: $0 -p ps -n \"POWERSTORE-QD,POWERSTORE-RR,POWERSTORE-NUMA\""
	echo ""
}

plottype="jpeg"
nonamespace=0

OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "p:hn" opt; do
	case "$opt" in
			p)
				plottype=$OPTARG
			;;
			h)
				display_full_help >&2
				exit 0
			;;
			n)
				nonamespace=1
			;;
			*)
				display_help >&2
				exit 1
			;;
	esac
done

shift "$((OPTIND-1))"   # Discard the options and sentinel --

if [ $# -lt 1 ]; then
	echo ""
	echo " Insuffient args"
    display_help >&2
    exit 3
fi

filelist="$1"

IFS=',' read -ra ADDR <<< "${filelist}"
for inputfile in "${ADDR[@]}"; do
	if ! [ -f ${inputfile} ]; then
		echo "input file $inputfile does not exist."
		exit 1
	fi
done

fiotxt="fio randrw workload"
if [ -f fio.txt ]; then
	fiotxt="$(cat fio.txt)"
fi

for inputfile in "${ADDR[@]}"; do

	disk=$(head ${inputfile} | grep -m 1 "nvme[0-9]*n" | awk '{print $3}')

	if [ -z "${disk}" ]; then
	echo "No disk found matching \"nvme[0-9]*n\" at begining of ${inputfile}"
		exit 1
	fi

	ctrl=$(head ${inputfile} | grep -m 1 "nvme[0-9]*n" | awk '{print $3}' |  sed 's/n[0-9]*$//')
	ns=$(head ${inputfile} | grep -m 1 "nvme[0-9]*n" | awk '{print $3}' |  sed 's/^nvme[0-9]*//')

	if [ ${nonamespace} -eq 1 ]; then
		top=$(grep ${ctrl} ${inputfile} | grep ${ns} | grep -v "${disk}" | awk '{print $12}' | sort -n -r | uniq | head -n 1)
	else
		top=$(grep ${ctrl} ${inputfile} | grep ${ns} | awk '{print $12}' | sort -n -r | uniq | head -n 1)
	fi

	ptop="Top number of outstanding I/O = ${top}"
	add_top=$(expr "$top" / 10)
	((top = $top+$add_top))

	mkdir -p data

	echo "set xdata time" > ${inputfile}.gpd
	echo "set xlabel \"TIME (MIN:SEC)\"" >> ${inputfile}.gpd
	echo "set ylabel \"INFLIGHT I/O\"" >> ${inputfile}.gpd
	echo "set title \"${inputfile}\\n${fiotxt}\\n${ptop}\"" >> ${inputfile}.gpd

	case "$plottype" in
		"jpeg")
			echo -n "Creating ${inputfile}.jpeg for "
			echo "set terminal jpeg nointerlace giant size 1440,900 nocrop enhanced" >> ${inputfile}.gpd
			echo "set output \"${inputfile}.jpeg\"" >> ${inputfile}.gpd
			;;
		"ps")
			echo -n "Creating ${inputfile}.ps for "
			echo "set terminal postscript" >> ${inputfile}.gpd
			echo "set output \"${inputfile}.ps\"" >> ${inputfile}.gpd
			;;
		"png")
			echo -n "Creating ${inputfile}.png for "
			echo "set terminal pngcairo" >> ${inputfile}.gpd
			echo "set terminal png size 1024,768" >> ${inputfile}.gpd
			echo "set output \"${inputfile}.png\"" >> ${inputfile}.gpd
			;;
			*)
			echo " Invlaid arg: $plottype"
			exit 1
			;;
	esac

	paths=($(grep ${ctrl} ${inputfile} | grep ${ns} | awk '{print $3}' | sort -r | uniq))
	echo "$paths"

	echo -n "plot [*:*][0:${top}]" >> ${inputfile}.gpd

	i=1
	for fdisk in "${paths[@]}"
	do
		trans="$(grep -A 3 "${fdisk}" cfgs/${inputfile}.cfg | grep transport | sed 's/^transport\s*://' | sed 's/ /-/g')"
		grep "${fdisk}" ${inputfile} | awk '{print $12}' > data/${inputfile}${trans}-${fdisk}-${i}
		grep -v 0 data/${inputfile}${trans}-${fdisk}-${i} >& /dev/null
		if test "$?" != "0"; then
		  echo "$i $fdisk returned no data."
		  rm data/${inputfile}${trans}-${fdisk}-${i}
		else
			echo "$i $fdisk == data/${inputfile}${trans}-${fdisk}-${i}"
			if [ "${disk}" == "${fdisk}" ]; then
				if [ ${nonamespace} -eq 0 ]; then
					echo -n " \"data/${inputfile}${trans}-${fdisk}-${i}\" using :1 with lines," >> ${inputfile}.gpd
				fi
			else
				echo -n " \"data/${inputfile}${trans}-${fdisk}-${i}\" using :1 with lines," >> ${inputfile}.gpd
			fi
			((i++))
		fi
	done

	echo "" >> ${inputfile}.gpd

	echo "gluplot -p ${inputfile}.gpd"
	gnuplot -p ${inputfile}.gpd

	echo "Done with $inputfile"
	echo ""
done

