# Linux NVMe iopolicy tests

This repository contains scripts use to generage work loads and collect the
data that can be used to analyze different nvme iopolicies used by the
nvme-core mulipathing module.

## Prerequsites 

Testbed setup should include an NVMe-oF multipath capabile target (a storage
array or Linux soft-target) with at least 4 paths (the more paths the better)
serving a single 200GB namespace, and a NVMe-oF host system. Best to use real
hardware if you can.

You will need root access to your host. All tests will be run from the `root`
account on the NVMe-of host.

Install the following packages on your NVMe-oF host:

```
# on Centos-stream-9
dnf config-manager --set-enabled crb
dnf install -y epel-release epel-next-release
dnf install -y fio sysstat gnuplot gimp
```

## Quickstart

1. clone this repository on your test host. 
2. log into the `root` account, you'll need two or three login sessions to run the test
* one to run the fio command 
* one to run the collection script
* one to run the iostat command (if desired)
3. `cd` to a scratch subdirectory
* both the fio script and the data collection scripts will create data collection files in your `pwd`
* it is recommended to create a new subdirectory for each test run
4. run the `start_collection.sh` script and follow the directions.

For example:

```
[root results12]# /home/test/setup/iopolicy/start_collection.sh "numa,round-robin,queue-depth,latency" ARRAY1 nvme12n1 300

Be sure to start fio in a separate shell with start_fio.sh

     "start_fio.sh <disk> <block_size> <runtime> <numjobs> <iodepth>"

 e.g: "/home/test/setup/iopolicy/start_fio.sh nvme12n1 1024k 1500 127 127"

Monitor progress with iostat

 "iostat -x ID $(cat /proc/diskstats | fgrep nvme12 | fgrep n1 | awk '{print $3}' | sort -r) 4"

Type any key to continue, e to exit:

nvme-subsys12/iopolicy is numa
setting iopolicy for nvme-subsys12 to numa
Creating file cfgs/ARRAY1-numa.cfg
Creating file /run/ARRAY1-numa
Done with /run/ARRAY1-numa
nvme-subsys12/iopolicy is numa
setting iopolicy for nvme-subsys12 to round-robin
Creating file cfgs/ARRAY1-round-robin.cfg
Creating file /run/ARRAY1-round-robin
Done with /run/ARRAY1-round-robin
nvme-subsys12/iopolicy is round-robin
setting iopolicy for nvme-subsys12 to queue-depth
Creating file cfgs/ARRAY1-queue-depth.cfg
Creating file /run/ARRAY1-queue-depth
Done with /run/ARRAY1-queue-depth
nvme-subsys12/iopolicy is queue-depth
setting iopolicy for nvme-subsys12 to latency
Creating file cfgs/ARRAY1-latency.cfg
Creating file /run/ARRAY1-latency
Done with /run/ARRAY1-latency
```

Following the test run the data collection files be created in your `pwd`.

```
[root results12]# ls
ARRAY1-latency  ARRAY1-numa  ARRAY1-queue-depth  ARRAY1-round-robin  ARRAY2-numa  ARRAY2-round-robin  cfgs  logs
```

You can generate the gnuplot graphs by running the `process_inflight-data.sh` script.

```
[root results12]# /home/test/setup/iopolicy/process_inflight-data.sh -n "ARRAY1-latency,ARRAY1-numa,ARRAY1-queue-depth,ARRAY1-round-robin"
Creating ARRAY1-latency.jpeg for nvme12n1
1 nvme12n1 == data/ARRAY1-latency-nvme12n1-1
2 nvme12c16n1 == data/ARRAY1-latency-fc-nvme12c16n1-2
3 nvme12c15n1 == data/ARRAY1-latency-fc-nvme12c15n1-3
4 nvme12c12n1 == data/ARRAY1-latency-fc-nvme12c12n1-4
5 nvme12c11n1 == data/ARRAY1-latency-fc-nvme12c11n1-5
gluplot -p ARRAY1-latency.gpd
Done with ARRAY1-latency

Creating ARRAY1-numa.jpeg for nvme12n1
1 nvme12n1 == data/ARRAY1-numa-nvme12n1-1
2 nvme12c16n1 returned no data.
2 nvme12c15n1 returned no data.
2 nvme12c12n1 == data/ARRAY1-numa-fc-nvme12c12n1-2
3 nvme12c11n1 returned no data.
gluplot -p ARRAY1-numa.gpd
Done with ARRAY1-numa

Creating ARRAY1-queue-depth.jpeg for nvme12n1
1 nvme12n1 == data/ARRAY1-queue-depth-nvme12n1-1
2 nvme12c16n1 == data/ARRAY1-queue-depth-fc-nvme12c16n1-2
3 nvme12c15n1 == data/ARRAY1-queue-depth-fc-nvme12c15n1-3
4 nvme12c12n1 == data/ARRAY1-queue-depth-fc-nvme12c12n1-4
5 nvme12c11n1 == data/ARRAY1-queue-depth-fc-nvme12c11n1-5
gluplot -p ARRAY1-queue-depth.gpd
Done with ARRAY1-queue-depth

Creating ARRAY1-round-robin.jpeg for nvme12n1
1 nvme12n1 == data/ARRAY1-round-robin-nvme12n1-1
2 nvme12c16n1 == data/ARRAY1-round-robin-fc-nvme12c16n1-2
3 nvme12c15n1 == data/ARRAY1-round-robin-fc-nvme12c15n1-3
4 nvme12c12n1 == data/ARRAY1-round-robin-fc-nvme12c12n1-4
5 nvme12c11n1 == data/ARRAY1-round-robin-fc-nvme12c11n1-5
gluplot -p ARRAY1-round-robin.gpd
Done with ARRAY1-round-robin
```

This creates .jpeg graph output files with gnuplot in your current directory.

```
[root results12]# ls *.jpeg
ARRAY1-latency.jpeg  ARRAY1-numa.jpeg  ARRAY1-queue-depth.jpeg  ARRAY1-round-robin.jpeg
```

