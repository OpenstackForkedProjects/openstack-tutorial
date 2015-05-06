#!/bin/bash

alias nossh="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

gre=95a67e12-a277-4e58-83f3-694d6ec53399


for i in {db,api,auth,image,volume,network}-node
do
nova boot --key-name antonio --flavor m1.small --image ubuntu-14.04-cloudarchive --nic net-id=8cf2499c-4d99-4623-a482-a762bacd862d --nic net-id=$gre $i
done

for i in compute-{1,2}
do
nova boot --key-name antonio --flavor m1.xlarge --image ubuntu-14.04-cloudarchive --nic net-id=8cf2499c-4d99-4623-a482-a762bacd862d --nic net-id=$gre $i
done


IPS=$(nova list --fields name,networks | grep vlan842|sed 's/.*vlan842=\(172.23.[0-9]\+\.[0-9]\+\).*/\1/g')
for ip in $IPS; do echo "$ip $(nossh  root@${ip} hostname).example.org" >> /tmp/hosts; done
for ip in $IPS; do priv=$(nossh root@$ip 'ifconfig eth1 | grep "inet addr" | sed "s/.*addr:\(10.[0-9]\+.[0-9]\+.[0-9]\+\).*/\1/g"'); host=$(nossh root@$ip hostname); echo "$priv $host" >> /tmp/hosts; done

for ip in $IPS; do cat /tmp/hosts | nossh root@$ip 'cat >> /etc/hosts'; done

### db node
ssh db-node.example.org aptitude install -y mysql-server python-mysqldb rabbitmq-server

rsync --chown=root:root -HaDSxv conf/db-node/ db-node.example.org:/


ssh db-node.example.org 'ip=$(ifconfig eth1|grep inet\ addr|sed "s/.*inet addr:\([0-9\.]*\) .*/\1/g"); echo NODE_IP_ADDRESS=$ip > /etc/rabbitmq/rabbitmq-env.conf; sed -i "s/127.0.0.1/$ip/g" /etc/mysql/my.cnf;'

ssh db-node.example.org service mysql restart

ssh db-node.example.org "rabbitmqctl add_user openstack gridka; rabbitmqctl set_permissions -p / openstack '.*' '.*' '.*'"

ssh db-node.example.org service rabbitmq-server restart

cat | ssh db-node.example.org mysql --password=root <<EOF
 CREATE DATABASE cinder;
 GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'gridka';
 CREATE DATABASE glance;
 GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY 'gridka';
 GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'gridka';
 CREATE DATABASE keystone;
 GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'gridka';
 GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'gridka';
 CREATE DATABASE neutron;
 GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'gridka';
 CREATE DATABASE nova;
 GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY 'gridka';
EOF

### auth-node
ssh auth-node.example.org aptitude install -y keystone python-mysqldb

rsync --chown=root:root -HaDSxv conf/auth-node/ auth-node.example.org:/

cat | ssh auth-node.example.org <<EOF
keystone-manage db_sync
service keystone restart
sleep 5

export OS_SERVICE_TOKEN=ADMIN
export OS_SERVICE_ENDPOINT=http://auth-node.example.org:35357/v2.0

keystone tenant-create --name=admin --description='Admin Tenant'
keystone tenant-create --name=service --description='Service Tenant'
keystone user-create --name=admin --pass=gridka --tenant=admin
keystone role-create --name=admin
keystone user-role-add --user=admin --role=admin --tenant=admin
keystone user-role-list --user admin --tenant admin
keystone service-create --name=keystone --type=identity --description='Keystone Identity Service'
keystone endpoint-create --publicurl http://auth-node.example.org:5000/v2.0 --adminurl http://auth-node.example.org:35357/v2.0 --internalurl http://auth-node:5000/v2.0 --region RegionOne --service keystone
keystone user-create --name=glance --pass=gridka
keystone user-role-add --tenant=service --user=glance --role=admin
keystone service-create --name glance --type image --description 'Glance Image Service'
keystone endpoint-create --region RegionOne --publicurl 'http://image-node.example.org:9292/v2' --adminurl 'http://image-node.example.org:9292/v2' --internalurl 'http://image-node:9292/v2' --region RegionOne --service glance
keystone user-create --name=cinder \
    --pass=gridka --tenant service
keystone user-role-add --tenant service --user cinder --role admin
keystone service-create --name cinder --type volume \
      --description 'Volume Service of OpenStack'
keystone endpoint-create --region RegionOne \
      --publicurl 'http://volume-node.example.org:8776/v1/\$(tenant_id)s' \
      --adminurl 'http://volume-node.example.org:8776/v1/\$(tenant_id)s' \
      --internalurl 'http://volume-node:8776/v1/\$(tenant_id)s' \
      --region RegionOne --service cinder
keystone user-create --name=nova --pass=gridka --tenant service
keystone user-role-add --tenant service --user nova --role admin
keystone service-create --name nova --type compute --description 'Compute Service of OpenStack'
keystone endpoint-create --region RegionOne \
      --publicurl 'http://api-node.example.org:8774/v2/\$(tenant_id)s' \
      --adminurl 'http://api-node.example.org:8774/v2/\$(tenant_id)s' \
      --internalurl 'http://api-node:8774/v2/\$(tenant_id)s' \
      --service nova
keystone service-create --name ec2 --type ec2 \
      --description 'EC2 service of OpenStack'
keystone endpoint-create --region RegionOne \
      --publicurl 'http://api-node.example.org:8773/services/Cloud' \
      --adminurl 'http://api-node.example.org:8773/services/Admin' \
      --internalurl 'http://api-node:8773/services/Cloud' \
      --service ec2
keystone user-create --name=neutron --pass=gridka
keystone user-role-add --user=neutron --tenant=service --role=admin
keystone service-create --name=neutron --type=network --description="OpenStack Networking Service"
keystone endpoint-create \
         --region RegionOne \
         --service neutron \
         --publicurl http://network-node.example.org:9696 \
         --adminurl http://network-node.example.org:9696 \
         --internalurl http://network-node:9696
EOF

### image-node

ssh image-node.example.org aptitude install -y glance python-mysqldb

rsync --chown=root:root -HaDSxv conf/image-node/ image-node.example.org:/

ssh image-node.example.org 'glance-manage db_sync; service glance-api restart; service glance-registry restart'


## api node

ssh api-node.example.org apt-get install -y nova-novncproxy novnc nova-api nova-ajax-console-proxy nova-cert nova-conductor nova-consoleauth nova-doc nova-scheduler python-novaclient openstack-dashboard

rsync --chown=root:root -HaDSxv conf/api-node/ api-node.example.org:/

ssh api-node.example.org 'ip=$(ifconfig eth1|grep inet\ addr|sed "s/.*inet addr:\([0-9\.]*\) .*/\1/g"); sed -i "s/%MYIP%/$ip/g" /etc/nova/nova.conf'

ssh api-node.example.org nova-manage db sync

ssh api-node.example.org 'sed -i s/^OPENSTACK_HOST.*/OPENSTACK_HOST="auth-node.example.org"/g /etc/openstack-dashboard/local_settings.py; service apache2 restart'

ssh api-node.example.org 'for serv in nova-{api,conductor,scheduler,novncproxy,consoleauth,cert}; do service $serv restart; done'

### volume-node

# create and atatch volume
nova volume-create --display-name cinder 100
id=$(nova volume-list | grep cinder|cut -d'|' -f2)
nova volume-attach volume-node $id

ssh volume-node.example.org apt-get install -y cinder-api cinder-scheduler cinder-volume open-iscsi python-mysqldb  python-cinderclient

ssh volume-node.example.org 'pvcreate /dev/vdb; vgcreate cinder-volumes /dev/vdb'

rsync --chown=root:root -HaDSxv conf/volume-node/ volume-node.example.org:/

ssh volume-node.example.org 'ip=$(ifconfig eth1|grep inet\ addr|sed "s/.*inet addr:\([0-9\.]*\) .*/\1/g"); sed -i "s/%MYIP%/$ip/g" /etc/cinder/cinder.conf'

ssh volume-node.example.org cinder-manage db sync

ssh volume-node.example.org for serv in cinder-{api,volume,scheduler}; do service $serv restart; done


### network-node

ssh network-node.example.org apt-get install -y python-mysqldb neutron-server neutron-dhcp-agent neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent

rsync --chown=root:root -HaDSxv conf/network-node/ network-node.example.org:/

ssh network-node.example.org sysctl -p /etc/sysctl.conf

id=$(keystone  tenant-get service|grep id|cut -d'|' -f3 | tr -d ' ')

ssh network-node.example.org "sed -i s/%NOVA_TENANT_ID%/$id/g" /etc/neutron/neutron.conf

ssh network-node.example.org 'ip=$(ifconfig eth1|grep inet\ addr|sed "s/.*inet addr:\([0-9\.]*\) .*/\1/g"); sed -i "s/%MYIP%/$ip/g" /etc/neutron/plugins/ml2/ml2_conf.ini'

ssh network-node.example.org neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno

ssh network-node.example.org 'for i in neutron-server neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent ; do service $i restart; done'


### compute-node

ssh compute-1.example.org apt-get install -y nova-compute-qemu neutron-plugin-openvswitch-agent neutron-plugin-ml2 python-libguestfs libguestfs-tools

rsync --chown=root:root -HaDSxv conf/compute-node/ compute-1.example.org:/

ssh compute-1.example.org 'ip=$(ifconfig eth1|grep inet\ addr|sed "s/.*inet addr:\([0-9\.]*\) .*/\1/g"); sed -i "s/%MYIP%/$ip/g" /etc/nova/nova.conf /etc/neutron/plugins/ml2/ml2_conf.ini'

ssh compute-1.example.org 'uuidgen > /etc/machine-id'

ssh compute-1.example.org 'service nova-compute restart; service neutron-plugin-openvswitch-agent restart'



# Note: you have to load nf_conntrack_proto_gre, otherwise a gre packet will be marked as INVALID.
# The behavior could be different depending on the kernel version. Strangely enough, even though many nf_conntrack* modules are loaded, nf_conntrack_proto_gre is not.
# Also check http://www.spinics.net/lists/netfilter/msg55920.html
