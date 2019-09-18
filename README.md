# Kernel Slab allocator script

# Problem Description:
We are chasing an issue where slab allocator is not releasing task_struct slab objects allocated by cgroups and we are wondering if this is a known issue or an expected behavior ?
If we stress test the system and spawn multiple tasks with different cgroups, number of active allocated task_struct objects will increase but kernel will never release those memory later on, even though if system goes to the idle state with lower number of the running processes.

# What does this test do ?

To test this, we have prepared a bash script that would create 1000 cgroups and it will spawn 100,000 bash tasks. 
This bash scipt will create multiple cgroups and it will stresstest the linux kernel by spawining multiple tasks at the same time.
Test shows that number of allocated slabs have been increased even though those task are completed adn the allocated memory won't get released unless someone manaually shrink the allocated slabs by writing to /sys/kernel/slab/<slab caches>/shrink sysfs files.


# Prerequisite
Kernel needs to have compiled with CONFIG_DEBUG_SLAB=y  which is usually the default configuration
also this script us using cgroutp tools which can be intalled on Ubuntu by running the following command:
```
sudo apt-get install cgroup-tools
```

Test Result for spawning 100,000 tasks on Ubuntu 19.04 with kernel version 5.0.0:

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


As it is shown above, number of active task_struct slabs has been increased from 736 to 11404 objects during the test. System keeps 11404 task_struct objects in the idle time where only 334 tasks is running. 
This huge number of active task_struct slabs it is not normal and a huge fraction of that memory can be - released to system memory pool. If we write to slab’s shrink systf entry, then kernel will release deactivated objects and it will free up the related memory, but it is not happening automatically by kernel as it was expected.

Following line is the command that would release those zombie objects:

```
# for file in /sys/kernel/slab/*; do echo 1 > $file/shrink; done
```

We know that some of slab caches are supposed to remain allocated until system really need that memory. 
So in one test we tried to consume all available system memory in a hope that kernel would release the above Memory but it didn’t happened and "out of memory killer" started killing processes and no memory got released by kernel slab allocator.

In recent systemd releases, CGroup memory accounting has been enabled by default and systemd will create multiple cgroups to run different software daemons. Although we have called this test as an stress test but this situation may happen in normal system boot time where systemd is trying to load and run multiple instances of programs daemons with different cgroups.
This issue only manifest itself when cgroup are actively in use. I've confirmed that this issue is present  in Kernel V4.19.66, Kernel V5.0.0 (Ubuntu 19.04) and latest Kernel Release V5.3.0.
Any comment and or hint would be greatly appreciated.
Here is some related kernel configuration while this test were done:

```
$ grep SLAB  .config
# CONFIG_SLAB is not set
CONFIG_SLAB_MERGE_DEFAULT=y
# CONFIG_SLAB_FREELIST_RANDOM is not set # CONFIG_SLAB_FREELIST_HARDENED is not set

#grep SLUB  .config
CONFIG_SLUB_DEBUG=y
# CONFIG_SLUB_MEMCG_SYSFS_ON is not set
CONFIG_SLUB=y
CONFIG_SLUB_CPU_PARTIAL=y
# CONFIG_SLUB_DEBUG_ON is not set
# CONFIG_SLUB_STATS is not set

$ grep KMEM  .config
CONFIG_MEMCG_KMEM=y
# CONFIG_DEVKMEM is not set
CONFIG_HAVE_DEBUG_KMEMLEAK=y
# CONFIG_DEBUG_KMEMLEAK is not set
```


# child_process.sh 
The test script will automatically create following bash script which will be used to run as test tasks.

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

