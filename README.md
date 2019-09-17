# Kernel Slab allocator script

It looks like kernel doesn't free up the allocated slabs for tasks that are running under CGroups and the memory won't be released automatically.

This bash scipt will create multiple cgroups and it will stresstest the linux kernel by spawining multiple tasks at the same time.
Test shows that number of allocated slabs have been increased even though those task are completed adn the allocated memory won't get released unless someone manaually shrink the allocated slabs by writing to /sys/kernel/slab/<slab caches>/shrink sysfs files.

#Prerequisite
Kernel needs to have compiled with CONFIG_DEBUG_SLAB=y  which is usually the default configuration
also this script us using cgroutp tools which can be intalled on Ubuntu by running the following command:
```
sudo apt-get install cgroup-tools
```

Test Result for spawning 50000 tasks on Ubuntu 19.04 with kernel version 5.0.0:
```
# uname -a
Linux ubuntu 5.0.0-27-generic #28-Ubuntu SMP Tue Aug 20 19:53:07 UTC 2019 x86_64 x86_64 x86_64 GNU/Linux

# ./cgtest.sh 
------------- system initial statistics -------------
Slab:             419196 kB
SReclaimable:     123788 kB
SUnreclaim:       295408 kB
# name            <active_objs> <num_objs> <objsize> <objperslab> <pagesperslab> : tunables <limit> <batchcount> <sharedfactor> : slabdata <active_slabs> <num_slabs> <sharedavail>
task_struct          735    990   5888    5    8 : tunables    0    0    0 : slabdata    198    198      0
Number of running processes : 334

------------- after loading tasks -------------
Slab:             948932 kB
SReclaimable:     125816 kB
SUnreclaim:       823116 kB
# name            <active_objs> <num_objs> <objsize> <objperslab> <pagesperslab> : tunables <limit> <batchcount> <sharedfactor> : slabdata <active_slabs> <num_slabs> <sharedavail>
task_struct        11404  11665   5888    5    8 : tunables    0    0    0 : slabdata   2333   2333      0
Number of running processes : 334
```


as it is shown above number of active task_struct slabs has been increased from 736 to 11404 while system is only running 334 tasks at idle time.

Cgroup memory accounting has been enabled in newer systemd released and systemd will create multiple cgroup to run different software deamons.
Although we have called this test a an stress test but this situation may happens at normal system boot times where systemd is trying to load and run multiple programs with different cgroups.
This issue only manifest itself when cgroup are activly used. I've confirmed that this issue is present in Kernel V4.19.66 V5.0.0 and latest Kernel Relaes 5.3.0.

# child_process.sh 
The test script will automatically create following bash child bash script task which will be used to run test tasks.

```
#!/bin/bash
# check if it is called as a worker script
if [ "$1" != "" ]
then
	eval "$@"
	exit
fi
# it is called as an scheduler script
sleep 2
for i in {1..100}
do	
	./child_process.sh sleep 1;echo something > /dev/null & 2>&1
done
```

