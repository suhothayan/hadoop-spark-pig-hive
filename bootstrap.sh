#!/bin/bash

: ${HADOOP_PREFIX:=/usr/local/hadoop}
: ${SPARK_PREFIX:=/usr/local/spark}
export HADOOP_HOME="/usr/local/hadoop"
export SPARK_HOME="/usr/local/spark"

$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
$SPARK_PREFIX/conf/spark-env.sh

rm /tmp/*.pid

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

# altering the core-site configuration
sed s/HOSTNAME/$HOSTNAME/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml


service ssh start
nohup $HADOOP_PREFIX/sbin/start-dfs.sh &>/dev/null &
nohup $HADOOP_PREFIX/sbin/start-yarn.sh &>/dev/null &
nohup $SPARK_PREFIX/sbin/start-all.sh &>/dev/null &
echo "Waiting for hdfs to exit from safemode"

while ! nc -z localhost 9000; do
  sleep 1 # wait for 1 second before check again
done

hdfs dfsadmin -safemode wait
#
# $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/hive
# $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/hive/warehouse
# $HADOOP_PREFIX/bin/hdfs dfs -mkdir /tmp
# $HADOOP_PREFIX/bin/hdfs dfs -chmod g+w /user/hive/warehouse
# $HADOOP_PREFIX/bin/hdfs dfs -chmod g+w /tmp
#
# nohup $HADOOP_PREFIX/sbin/stop-dfs.sh &>/dev/null &
# nohup $HADOOP_PREFIX/sbin/stop-yarn.sh &>/dev/null &

echo "Started"

# if [[ $1 == "-d" ]]; then
#   while true; do sleep 1000; done
# fi
#
# if [[ $1 == "-bash" ]]; then
/bin/bash
# fi
