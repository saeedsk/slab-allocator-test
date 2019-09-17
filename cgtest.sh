#!/bin/bash

task="sleep 1;echo something"
taskno=1000

create_child_task_script()
{
echo -n "#!/bin/bash
# check if it is called as a worker script
if [ \"\$1\" != \"\" ]
then
	eval \"\$@\"
	exit
fi
# it is called as an scheduler script
sleep 2
for i in {1..100}
do	
	./child_process.sh $task > /dev/null & 2>&1
done
" > ./child_process.sh
chmod 755 child_process.sh
}

show_stat () {
	cat /proc/meminfo  | grep 'Slab\|SReclaimable\|SUnreclaim'
	cat /proc/slabinfo | grep size
	cat /proc/slabinfo | grep task_struct
	echo -n "Number of running processes : "; ps aux | wc -l
}

# create a child task script
create_child_task_script
for file in /sys/kernel/slab/*; do echo 1 > $file/validate; done 
for file in /sys/kernel/slab/*; do echo 1 > $file/shrink; done 

echo "------------- system initial statistics -------------"
show_stat 

for ((cg=1;cg<=$taskno;cg++))
do
	cgcreate -g memory:/test$cg
done

#cg stress test
for ((i=1;i<=$taskno;i++))
do
	cgexec -g memory:/test$i sh ./child_process.sh &	
done
echo "------------- after loading tasks -------------"
sleep 5
show_stat 
