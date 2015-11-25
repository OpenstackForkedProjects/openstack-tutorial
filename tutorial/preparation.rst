
---------------------------------
Preparation of the infrastructure
---------------------------------

During this tutorial, each one of you will have access to an OpenStack
private cloud and will create one instance per service:

* ``db-node``:  runs *MySQL* and *RabbitMQ*

* ``auth-node``: runs *keystone*, the identity and authentication
  service

* ``image-node``: runs **glance**, the image storage, composed of the
  *glance-api* and glance-registry* services

* ``compute-node``: runs most of the **nova** service: *nova-api*,
  *nova-scheduler*, *nova-conductor* and *nova-console*. It also runs
  the web frontend of OpenStack (*horizon*)

* ``volume-node``: runs **cinder**, the volume manager, composed of
  the *cinder-api*, *cinder-scheduler* and *cinder-volume* services

* ``network-node``: runs **neutron**, the NaaS manager. 

* ``hypervisor-1``: runs *nova-compute*

* ``hypervisor-2``: runs *nova-compute*

However, due to limitation on the number of public IPs we have available 
on the testbed, we will create one single bastion VM with a floating IP and
use it to connect and manage the OpenStack VMs and also to forward traffic 
destinated to the API to the correct VM.

Network configuration
---------------------

The big picture
+++++++++++++++

Services that usually need access to the public network in an
OpenStack deployment are those that implements the network APIs and
provice network connectivity to the VMs:

+--------------+---------------------------------+
| node         | service requiring public access |
+==============+=================================+
| compute-node | nova-api, horizon               |
+--------------+---------------------------------+
| volume-node  | cinder-api                      |
+--------------+---------------------------------+
| image-node   | glance-api                      |
+--------------+---------------------------------+
| auth-node    | keystone                        |
+--------------+---------------------------------+
| network-node | neutron-api + NAT               |
+--------------+---------------------------------+

Also, all the OpenStack nodes (including the hypervisors) are usually
connected to an internal network used for the internal communication
among all the services.

In a scalable and highly available deployment you would usually put
all the API services behind a load balancer. In this case, only the
network node(s) will need direct access to at least one public
network.

During this workshop, however, we cannot provide the amount of public
IPs that would be needed to test a fully functional OpenStack cloud to
all of the attendees, therefore we will use a bastion host to redirect
(using DNAT) the traffic to the correct service.

.. note: there are other practical reasons: unless you give neutron an
.. interface directly on the public network, floating IPs will not
.. work. Also, you should pre-allocate the floating IPs so that
.. neutron could use them. And, again, you need to disable the
.. port-security-enabled feature...


To mimic a real-world deployment, we will use two networks, one to be
intended as the management network (`openstack-priv`), the other would
be the public network (`openstack-public`).

+------+-----------------------+-------------------------------------------------+
| iface| network               | IP range                                        |
+======+=======================+=================================================+
| eth0 | openstack-priv        | 192.168.1.3 - 192.168.1.254                     |
+------+-----------------------+-------------------------------------------------+
| eth1 | openstack-public      | 10.0.0.3 - 10.0.0.254                           |
+------+-----------------------+-------------------------------------------------+

*(you can use different IP networks, but this documentation assumes
these IPv4 ranges for these networks)*

Only the bastion host and the network node will have an interface on
the `openstack-public` network. All the other hosts will have at least
one interface in `openstack-priv` network.

On a production environment it's likely that you have even more
internal networks, possibly associated to different physical
interfaces or at least different VLANs.

A complex production setup would probably have:

* a management network, to monitor and manage the physical nodes with
  your configuration and management system of your choice
* a service network, dedicated for the openstack internal traffic
  (RabbitMQ, MySQL, internal API)
* an *integration network*, used to transport the VM-VM traffic, from
  hypervisor to hypervisor and from the hypervisor to the network
  node.
* possibly, a storage network
* possibly, a completely independent network for HA (to avoid split
  brain, and depending on your HA setup)

For simplicity, during this workshop the `openstack-priv` network will
be used for all these purposes.

.. The *OpenStack private network* is the internal network of the
.. OpenStack virtual machines. The virtual machines need to communicate
.. with the network node, (unless a "multinode setup is used") and among
.. them, therefore this network is configured only on the network node
.. (that also need to have an IP address in it) and the compute nodes,
.. which only need to have an interface on this network attached to a
.. bridge the virtual machines will be attached to. On a production
.. environment you would probably use a separated L2 network for this,
.. either by using VLANs or using a second physical interface. This is
.. why in this tutorial we have added a second interface to the compute
.. nodes, that will be used for VM-VM communication and to communicate
.. with the network node.

The following diagram shows both the network layout of the physical
machines and of the virtual machines running in it:

FIXME: change diagram

.. image:: ../images/network_diagram.png

How to connect to the VMs
+++++++++++++++++++++++++

There is still a problem though: we only have one VM we can access
from the lab: the bastion host. We will use DNAT to redirect the
service ports to the internal hosts, but how can we ssh on the VMs to
manage them?

There are multiple options:

* use `sshuttle <https://github.com/apenwarr/sshuttle>`_ (strongly
  suggested)
* ssh to the bastion host and then ssh to the openstack VMs using the
  IPs in the `openstack-public` network
* use DNAT (port forwarding) to redirect, for instance, tcp/2021 on
  bastion host to port tcp/22 on auth-node; tcp/2022 to tcp/22 on
  compute node etc etc.
* use ssh port forwarding to redirect, for each node, a local port on
  your laptop to the remote tcp/22 port of the node

We strongly suggest to use sshuttle, and to modify your local
``/etc/hosts`` file to easily access the OpenStack VMs using the
names.

**FIXME: run sshuttle with the proper options**
Since we are using DHCP for both openstack-{priv,public} network,
you should configure the ``/etc/hosts`` file on all of your virtual 
machines in order to be able to connect to them using only the hostname.

After you started all of your virtual machines, you could do something like::

     FIXME: to be done over sshuttle?
     user@ubuntu:~$ IPS=$(nova list --fields name,networks | grep openstack-priv|sed 's/.*openstack-priv=\(192.168.[0-9]\+\.[0-9]\+\).*/\1/g')
     user@ubuntu:~$ for ip in $IPS; do echo "$ip $(ssh  root@${ip} hostname).example.org" >> /tmp/hosts; done
     user@ubuntu:~$ for ip in $IPS; do priv=$(ssh root@$ip 'ifconfig eth1 | grep "inet addr" | sed "s/.*addr:\(10.0.0.[0-9]\+\).*/\1/g"'); host=$(ssh root@$ip hostname); echo "$priv $host" >> /tmp/hosts; done

Then, add this file to ``/etc/hosts`` on all the machines::

    user@ubuntu:~$ for ip in $IPS; do cat /tmp/hosts | ssh root@$ip 'cat >> /etc/hosts'; done



Preparing the virtual machines
------------------------------

Open the browser at http://cscs2015.s3it.uzh.ch/horizon and login using one
of the very secret login/password we gave you. Each one of you will
have a project on its own, called `projectNN` and an user belonging to
that project, called `userNN`. The teacher will use `user01` and `project01` 
while the tutor will user `user20` and `project20`.

Since we are going to use the bastion host for connecting to the VMs where the 
OpenStack services will be installed we have to be ensure ourself access is 
to those VMs is possible. There are two different ways to achieve that:

- enable the `ForwardAgent` in your ssh configuration,
- create a new keypair on the bastion host and add it to
  your account on https://cscs2015.s3it.uzh.ch.

You can create the virtual machines either via web interface or, if
you install on your laptop the following packages, also from the
command line:

* python-novaclient
* python-keystoneclient
* python-cinderclient
* python-neutronclient
* python-glanceclient

Hands-on preparing the environment
----------------------------------

First of all create a network which will simualte the "public" network in real world scenario::

   user@ubuntu:~$ neutron net-create openstack-public

   +-----------------------+--------------------------------------+
   | Field                 | Value                                |
   +-----------------------+--------------------------------------+
   | admin_state_up        | True                                 |
   | id                    | c5217907-ead8-4862-afda-bea30a79cb5a |
   | mtu                   | 0                                    |
   | name                  | openstack-public                     |
   | port_security_enabled | True                                 |
   | router:external       | False                                |
   | shared                | False                                |
   | status                | ACTIVE                               |
   | subnets               |                                      |
   | tenant_id             | f4c492a4c3744a85bc654ecbe592d478     |
   +-----------------------+--------------------------------------+

Then create a subnet inside the network we have just created:: 

   user@ubuntu:~$ neutron subnet-create openstack-public 10.0.0.0/24 --name openstack-public-subnet --allocation-pool start=10.0.0.3,end=10.0.0.254 --enable-dhcp --gateway 10.0.0.1 
   
   Created a new subnet:
   +-------------------+--------------------------------------------+
   | Field             | Value                                      |
   +-------------------+--------------------------------------------+
   | allocation_pools  | {"start": "10.0.0.2", "end": "10.0.0.254"} |
   | cidr              | 10.0.0.0/24                                |
   | dns_nameservers   |                                            |
   | enable_dhcp       | True                                       |
   | gateway_ip        | 10.0.0.1                                   |
   | host_routes       |                                            |
   | id                | b832df6d-6d89-42a3-8471-c5bc971a8802       |
   | ip_version        | 4                                          |
   | ipv6_address_mode |                                            |
   | ipv6_ra_mode      |                                            |
   | name              | openstack-public-subnet                    |
   | network_id        | c5217907-ead8-4862-afda-bea30a79cb5a       |
   | subnetpool_id     |                                            |
   | tenant_id         | f4c492a4c3744a85bc654ecbe592d478           |
   +-------------------+--------------------------------------------+

Create a router to be used of connecting the 'uzh-public' (so, Internet) to the 'openstack-public' network::
  
    user@ubuntu:~$ neutron router-create openstack-public-to-uzh-public

    Created a new router:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | external_gateway_info |                                      |
    | id                    | 3024c6b6-daf5-4ce1-8456-1a29e80194c3 |
    | name                  | openstack-public-to-uzh-public       |
    | routes                |                                      |
    | status                | ACTIVE                               |
    | tenant_id             | f4c492a4c3744a85bc654ecbe592d478     |
    +-----------------------+--------------------------------------+

Add an interface (it is like adding a physical patch) from the openstack-public-subnet to the router we have just created::

    user@ubuntu:~$ neutron router-interface-add openstack-public-to-uzh-public openstack-public-subnet
    Added interface 38f22ccf-88cd-4a4f-8719-82caad291b60 to router openstack-public-to-uzh-public.

Set the router to act as a gateway for the uzh-public network::

    user@ubuntu:~$ neutron router-gateway-set openstack-public-to-uzh-public uzh-public
    Set gateway for router openstack-public-to-uzh-public

Now we go on with creating the network which will simulate the private network of the OpenStack installation::

    user@ubuntu:~$ neutron net-create openstack-priv
    Created a new network:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | id                    | d2af2831-6a4e-4672-8a9b-022958ebc870 |
    | mtu                   | 0                                    |
    | port_security_enabled | True                                 |
    | name                  | openstack-priv                       |
    | router:external       | False                                |
    | shared                | False                                |
    | status                | ACTIVE                               |
    | subnets               |                                      |
    | tenant_id             | f4c492a4c3744a85bc654ecbe592d478     |
    +-----------------------+--------------------------------------+

Create a subnet in the network we have just created:: 

    user@ubuntu:~$ neutron subnet-create openstack-priv 192.168.1.0/24 --name openstack-priv-subnet --dns-nameserver "130.60.128.3" --dns-nameserver "130.60.64.51" --allocation-pool start=192.168.1.3,end=192.168.1.254 --enable-dhcp --no-gateway
    Created a new subnet:
    +-------------------+--------------------------------------------------+
    | Field             | Value                                            |
    +-------------------+--------------------------------------------------+
    | allocation_pools  | {"start": "192.168.1.3", "end": "192.168.1.254"} |
    | cidr              | 192.168.1.0/24                                   |
    | dns_nameservers   | 130.60.128.3                                     |
    |                   | 130.60.64.51                                     |
    | enable_dhcp       | True                                             |
    | gateway_ip        |                                                  |
    | host_routes       |                                                  |
    | id                | 8ca24812-d535-4fa3-a094-90be24deaf91             |
    | ip_version        | 4                                                |
    | ipv6_address_mode |                                                  |
    | ipv6_ra_mode      |                                                  |
    | name              | openstack-priv-subnet                            |
    | network_id        | d2af2831-6a4e-4672-8a9b-022958ebc870             |
    | subnetpool_id     |                                                  |
    | tenant_id         | f4c492a4c3744a85bc654ecbe592d478                 |
    +-------------------+--------------------------------------------------+

In our setup we are going to use a "bastion VM" as a gateway for the rest of the OpenStack services. Since by default Ubuntu is bringing up only the first network interface and the routing between the "openstack-public" and the "uzh-public" is provided by the "openstack-public-to-uzh-public" router when starting the VM we have to ensure that "openstack-public" is provided via NIC1 as shown on the picture. 
    

.. image:: ../images/bastion_networking.png


Once the VM is up and running take note of the IP assigned on the openstack-priv
network and change the openstack-priv network to use that IP as a gateway::                  

   user@ubuntu:~$ neutron subnet-update openstack-priv-subnet --host-route destination=0.0.0.0/0,nexthop=<IP_OF_THE_BASTION_ON_THE_PRIV_NETWORK>

Next step is disabling the security constrains Neutron is a applying in order to avoid arp spoofing. In our case this optsion will prevent MASQUERADING to work properly. In order to do this you have to find the port used from the bastion host on the openstack-priv network::

   user@ubuntu:~$ neutron port-list | grep <IP_OF_THE_BASTION_ON_THE_PRIV_NETWORK>
   ede0a89a-4830-4780-a290-50c9cfd806a7 |      | fa:16:3e:18:93:cb | {"subnet_id": "c942c430-f819-4832-84a3-99da71323770", "ip_address": "<IP>"}

Disable the security groups and port security on that port::

   user@ubuntu:~$ neutron port-update --no-security-groups --port-security-enabled=False ede0a89a-4830-4780-a290-50c9cfd806a7

..    
    There is a problem with this option since Neutron is blocking the forwared connections. 
    Chain neutron-openvswi-s25c99e62-6 (1 references)
    pkts bytes target     prot opt in     out     source               destination         
    2159  176K RETURN     all  --  any    any     192.168.1.10         anywhere             MAC FA:16:3E:20:FC:5C /* Allow traffic from defined IP/MAC pairs. */
    2919  245K DROP       all  --  any    any     anywhere             anywhere             /* Drop traffic without an IP/MAC allow rule. */
    We fixed this by adding xtension_drivers = port_security in /etc/neutron/plugins/ml2/ml2_conf.ini. This will create the relative entry in the database so next time network is created the "port_security_enabled" filed will be available and operations over it will be grated 

When done with this go on with assigning a floating IP on uzh-public network. Please do it over the GUI, since more immediate.

Login to the bastion VM and configure the masquerading::

   root@bastion:~# dhclient eth1
   root@bastion:~# iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   root@bastion:~# iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
   root@bastion:~# iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
   root@bastion:~# echo 1 > /proc/sys/net/ipv4/ip_forward

You can persist those changes using by:

- use iptables-save to save the iptables rules,
- set net.ipv4.ip_forward=1 inside /etc/sysctl.conf. 

Assuming everything worked smoothly in the steps above you can start with booting all the VMs we will need for setting up the OpenStack installation::

    user@ubuntu:~$ nova net-list
    +--------------------------------------+------------------+------+
    | ID                                   | Label            | CIDR |
    +--------------------------------------+------------------+------+
    | 4cb131d5-5ece-4122-9014-ac069cd8d4a3 | uzh-public       | None |
    | 5a3feca5-2be5-4943-8f9d-9f3b8eb74c35 | openstack-priv   | None |
    | 7ff18d6e-12c1-41a9-b0c7-dabc7fc44eab | openstack-public | None |
    +--------------------------------------+------------------+------+

and you have a keypair named `bastion`, you can start the `db-node auth-node image-node volume-node api-node hypervisor-1 hypervisor-2` nodes with the following command::

    user@ubuntu:~$ for i in db-node auth-node image-node volume-node api-node hypervisor-1 hypervisor-2; do nova boot --key-name bastion --image ubuntu-trusty --flavor m1.small --nic net-id=<ID_OF_THE_OPENSTACK_PRIV_NETWORK> $i; done

Since the network node needs an interface on the openstack-public interface we have to start it seprately using the following command::

    user@ubuntu:~$ nova boot --key-name bastion --image ubuntu-trusty --flavor m1.small --nic net-id=<ID_OF_THE_OPENSTACK_PRIV_NETWORK> --nic net-id=<ID_OF_THE_OPENSTACK_PUB_NETWORK>network-node

Access the Virtual Machines
---------------------------

If you setup your access method correctly you should be able to login on all VMs from the bastion host.

You can see the IP address of the VM via web interface or using `nova` command::

    user@ubuntu:~$ nova list 
    +--------------------------------------+--------------+--------+------------+-------------+----------------------------------------------------------------------+
    | ID                                   | Name         | Status | Task State | Power State | Networks                                                             |
    +--------------------------------------+--------------+--------+------------+-------------+----------------------------------------------------------------------+
    | 728623a2-259b-46f7-a53e-9fcda839c75d | api-node     | ACTIVE | -          | Running     | openstack-priv=192.168.1.12                                          |
    | 2b5659df-95c9-45af-b0b4-7190c71fc3b6 | auth-node    | ACTIVE | -          | Running     | openstack-priv=192.168.1.9                                           |
    | 2b583336-1982-4055-bd50-b01568c4b033 | bastion      | ACTIVE | -          | Running     | openstack-priv=192.168.1.4; openstack-public=10.0.0.9, 130.60.24.111 |
    | 4cc83df7-a27b-40c3-8de6-e1a0ec384c15 | db-node      | ACTIVE | -          | Running     | openstack-priv=192.168.1.8                                           |
    | 67cf3888-20c9-45ec-a341-ab46a725a2eb | hypervisor-1 | ACTIVE | -          | Running     | openstack-priv=192.168.1.13                                          |
    | 16111abc-728e-4e83-a77d-360b645db3ca | hypervisor-2 | ACTIVE | -          | Running     | openstack-priv=192.168.1.14                                          |
    | 58510251-2c76-4795-9f02-1a6e93fddecd | image-node   | ACTIVE | -          | Running     | openstack-priv=192.168.1.10                                          |
    | 079d5549-2799-49ca-9bb2-0fa11c419edd | network-node | ACTIVE | -          | Running     | openstack-priv=192.168.1.15; openstack-public=10.0.0.10              |
    | 9504ef02-3897-4e7f-813b-bef14a7d68f5 | volume-node  | ACTIVE | -          | Running     | openstack-priv=192.168.1.11                                          |
    +--------------------------------------+--------------+--------+------------+-------------+----------------------------------------------------------------------+


You should be able to connect from the bastion host using regular user `ubuntu`::

    ubuntu@bastion:~$ ssh ubuntu@192.168.1.8
    The authenticity of host '192.168.1.8 (192.168.1.8)' can't be established.
    ECDSA key fingerprint is 5a:90:f5:aa:e7:61:63:d6:3b:ce:13:92:b9:32:5c:95.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '192.168.1.8' (ECDSA) to the list of known hosts.
    Welcome to Ubuntu 14.04.3 LTS (GNU/Linux 3.13.0-68-generic x86_64)
    ...
    ubuntu@db-node:~$ 


Install openstack repository and ntp
------------------------------------

Before starting with the installation of the services, it's a good
idea to

* install the openstack repository for Liberty on all the nodes
* upgrade the packages
* install NTP (not needed, but strongly recommended, especially when
  troubleshooting)

From the bastion host:

    root@bastion:$ for node in {db,auth,image,compute,volume,neutron}-node hypervisor-{1,2}; do
ssh $node 'apt-get install software-properties-common; add-apt-repository cloud-archive:liberty; apt-get update -y; apt-get upgrade -y; apt-get install -y ntp'
done

(can take a while, let's have a coffe in the meantime)
    
