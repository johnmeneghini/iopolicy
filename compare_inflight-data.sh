#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (c) 2024 John Meneghini <jmeneghi@redhat.com> All rights reserved.

display_help() {
	echo ""
	echo " usage: $0 [ -h | -p <ps | jpeg | png> ] <\"filename,filename,...\"> <output>"
	echo ""
	echo "   -h                      display help"
	echo "   -p  <type>              create postscript, jpeg or png output. the default is jpeg."
	echo "   <\"filename,filename\"> string of input files generated from collect_inflight_data.sh"
	echo "   <output>                name of output file."
	echo ""
	echo "  e.g.: $0 \"A400-RR,A400-QD,A400-NUMA\" A400"
	echo "  e.g.: $0 -p ps \"DISK1-RR,DISK1-QD,DISK1-NUMA\" DISK1"
	echo ""
}

plottype="jpeg"

OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "p:h" opt; do
	case "$opt" in
			p)
				plottype=$OPTARG
			;;
			h)
				display_help >&2
				exit 0
			;;
			*)
				display_help >&2
				exit 1
			;;
	esac
done

shift "$((OPTIND-1))"   # Discard the options and sentinel --

if [ $# -lt 2 ]; then
	echo ""
	echo " Insuffient args"
    display_help >&2
    exit 3
fi

filelist="$1"
output="$2"

top=0
IFS=',' read -ra ADDR <<< "${filelist}"
for inputfile in "${ADDR[@]}"; do
	if ! [ -f ${inputfile} ]; then
		echo "input file $inputfile does not exist."
		exit 1
	else
		disk=$(head ${inputfile} | grep -m 1 "nvme[0-9]*n" | awk '{print $3}')
		if [ -z "${disk}" ]; then
			echo "No disk found matching \"nvme[0-9]*n\" at begining of ${inputfile}"
			exit 1
		fi
		thistop=$(grep "${disk}" ${inputfile} | awk '{print $12}' | sort -n -r | uniq | head -n 1)
		if [[ $thistop -gt $top ]]; then
			top=$thistop
		fi
	fi
done

ptop="Top number of outstanding I/O = ${top}"
echo "$ptop"
add_top=$(expr "$top" / 10)
((top = $top+$add_top))

fiotxt="fio randrw workload"
if [ -f fio.txt ]; then
	fiotxt="$(cat fio.txt)"
fi

outputfile="${output}-COMPARE-IOPOLICY"

echo "set xdata time" > ${outputfile}.gpd
echo "set xlabel \"TIME (MIN:SEC)\"" >> ${outputfile}.gpd
echo "set ylabel \"INFLIGHT I/O\"" >> ${outputfile}.gpd
echo "set title \"${outputfile} - ${filelist} - \\n${fiotxt}\\n${ptop}\"" >> ${outputfile}.gpd

case "$plottype" in
	"jpeg")
		echo "Creating ${outputfile}.jpeg"
		echo "set terminal jpeg nointerlace giant size 1440,900 nocrop enhanced" >> ${outputfile}.gpd
		echo "set output \"${outputfile}.jpeg\"" >> ${outputfile}.gpd
		;;
	"ps")
		echo "Creating ${outputfile}.ps"
		echo "set terminal postscript" >> ${outputfile}.gpd
		echo "set output \"${outputfile}.ps\"" >> ${outputfile}.gpd
		;;
	"png")
		echo "Creating ${outputfile}.png"
		echo "set terminal pngcairo" >> ${outputfile}.gpd
		echo "set terminal png size 1024,768" >> ${outputfile}.gpd
		echo "set output \"${outputfile}.png\"" >> ${outputfile}.gpd
		;;
		*)
		echo " Invlaid arg: $plottype"
		exit 1
		;;
esac

mkdir -p data

echo -n "plot [*:*][0:${top}]" >> ${outputfile}.gpd
for inputfile in "${ADDR[@]}"; do
	i=1
	disk=$(head ${inputfile} | grep -m 1 "nvme[0-9]*n" | awk '{print $3}')
	paths=($(grep "${disk}" ${inputfile} | awk '{print $3}' | sort -r | uniq))
	for fdisk in "${paths[@]}"; do
		if [ "${disk}" == "${fdisk}" ]; then
			grep "${fdisk}" ${inputfile} | awk '{print $12}' > data/${inputfile}-${fdisk}
			grep -v 0 data/${inputfile}-${fdisk} >& /dev/null
			if test "$?" != "0"; then
				echo " $i $fdisk returned no data."
				rm data/${inputfile}-${fdisk}
			else
				echo "$i $fdisk == data/${inputfile}-${fdisk}"
				echo -n " \"data/${inputfile}-${fdisk}\" using :1 with lines," >> ${outputfile}.gpd
			fi
		else
			echo " $i ignoring disk \"${fdisk}\" : not equal to \"${disk}\""
		fi
		((i++))
	done
done

echo "" >> ${outputfile}.gpd

echo "gluplot -p ${outputfile}.gpd"
gnuplot -p ${outputfile}.gpd

echo ""
echo "Done with \"${filelist}\""
echo ""
