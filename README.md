# Kernel Slab allocator script

It looks like kernel doesn't free up the allocated slabs for tasks that are running under CGroups and the memory won't be released automatically.

This bash scipt will create multiple cgroups and it will stresstest the linux kernel by spawining multiple tasks at the same time.
Test shows that number of allocated slabs have been increased even though those task are completed adn the allocated memory won't get released unless someone manaually shrink the allocated slabs by writing to ''/sys/kernel/slab/<slab caches>/shrink'' sysfs files.

Test Result for spawning 50000 tasks on Ubuntu 19.04 with kernel 5.0:
```# uname -a
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
