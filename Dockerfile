# Creates pseudo distributed hadoop 2.9.2, Ubuntu 18.04, spark 2.4.3, pig 0.17.0, hive 2.3.5
#
# docker build -t suhothayan/hadoop-spark-pig-hive:2.9.2 .

FROM ubuntu:18.04
MAINTAINER Suhothayan

USER root

# install dev tools
RUN apt-get update
RUN apt-get install -y curl tar sudo openssh-server openssh-client rsync

# passwordless ssh
RUN rm -f /etc/ssh/ssh_host_dsa_key /etc/ssh/ssh_host_rsa_key /root/.ssh/id_rsa
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# java & vim
RUN apt-get update \
    && apt-get -y install openjdk-8-jdk \
    && apt-get -y install vim

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH $JAVA_HOME/bin:$PATH

# hadoop
RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.9.2/hadoop-2.9.2.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./hadoop-2.9.2 hadoop

ENV HADOOP_PREFIX /usr/local/hadoop
RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
#RUN . $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

RUN mkdir $HADOOP_PREFIX/input
RUN cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_PREFIX/input

# pseudo distributed
ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml
ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml

ADD mapred-site.xml $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
ADD yarn-site.xml $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

RUN $HADOOP_PREFIX/bin/hdfs namenode -format

# fixing the libhadoop.so like a boss
#RUN rm -rf  /usr/local/hadoop/lib/native/*
#RUN curl -Ls http://dl.bintray.com/sequenceiq/sequenceiq-bin/hadoop-native-64-2.9.2.tar|tar -x -C /usr/local/hadoop/lib/native/

ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

# # installing supervisord
# RUN yum install -y python-setuptools
# RUN easy_install pip
# RUN curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -o - | python
# RUN pip install supervisor
#
# ADD supervisord.conf /etc/supervisord.conf

# workingaround docker.io build error
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh
RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

RUN service ssh start && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/root
RUN service ssh start && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -put $HADOOP_PREFIX/etc/hadoop/ input

#Add hadoop to path
ENV PATH /usr/local/hadoop/bin:$PATH

# pig
RUN curl -s http://apache.mirror.anlx.net/pig/pig-0.17.0/pig-0.17.0.tar.gz | tar -xz -C /usr/local
ENV PIG_HOME /usr/local/pig-0.17.0/
RUN ln -s $PIG_HOME /usr/local/pig
ENV PATH $PATH:$PIG_HOME/bin

# hive
RUN curl -s http://apache.mirror.anlx.net/hive/hive-2.3.5/apache-hive-2.3.5-bin.tar.gz  | tar -xz -C /usr/local
ENV HIVE_HOME /usr/local/apache-hive-2.3.5-bin/
RUN ln -s $HIVE_HOME /usr/local/hive
ENV PATH $PATH:$HIVE_HOME/bin

RUN $HIVE_HOME/bin/schematool -dbType derby -initSchema

RUN apt-get install -y netcat

RUN service ssh start \
    && nohup $HADOOP_PREFIX/sbin/start-dfs.sh &>/dev/null & \
    nohup $HADOOP_PREFIX/sbin/start-yarn.sh &>/dev/null & \
    while ! nc -z localhost 9000; do sleep 1; done \
    && hdfs dfsadmin -safemode wait \
    && RUN $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/hive \
    && $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/hive/warehouse \
    && $HADOOP_PREFIX/bin/hdfs dfs -mkdir /tmp \
    && $HADOOP_PREFIX/bin/hdfs dfs -chmod g+w /user/hive/warehouse \
    && $HADOOP_PREFIX/bin/hdfs dfs -chmod g+w /tmp \
    && nohup $HADOOP_PREFIX/sbin/stop-dfs.sh &>/dev/null & \
    nohup $HADOOP_PREFIX/sbin/stop-yarn.sh &>/dev/null &

#mr job
RUN apt-get install -y python-pip \
    && pip install mrjob

# spark
RUN curl -s https://www-eu.apache.org/dist/spark/spark-2.4.3/spark-2.4.3-bin-without-hadoop-scala-2.12.tgz | tar -xz -C /usr/local
ENV SPARK_HOME /usr/local/spark-2.4.3-bin-without-hadoop-scala-2.12/
RUN ln -s $SPARK_HOME /usr/local/spark
ENV PATH $PATH:$SPARK_HOME/bin
ADD spark-env.sh $SPARK_HOME/conf/spark-env.sh

ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

ENTRYPOINT ["/etc/bootstrap.sh", "-d"]

EXPOSE 8031 8030 8032 8088 8033 40661 8040 13562 8042 50070 9000 50010 50075 50020 50090 8080 8081
