#!/bin/bash

# 输出详细执行日志
set -x

USAGE="Usage: control.sh (start|stop)"

CMD=$1

# 设置环境变量
if [ ! -d "/opt/cloudera/parcels/FLINK" ]; then
     ln -sv /opt/cloudera/parcels/ZOOKEEPER-* /opt/cloudera/parcels/ZOOKEEPER
fi
ZOOKEEPER_HOME=/opt/cloudera/parcels/ZOOKEEPER/lib/zookeeper


case $CMD in
    (start)
    exec exec $ZOOKEEPER_HOME/bin/zkServer.sh start 
    ;;

    (stop)
    exec exec $ZOOKEEPER_HOME/bin/zkServer.sh stop 
    ;;
    (*)
    echo "Don't understand [$CMD]"
    exit 1
    ;;
esac