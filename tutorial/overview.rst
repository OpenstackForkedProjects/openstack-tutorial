
-----------------
Tutorial overview
-----------------

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

* ``neutron-node``: runs **neutron**, the NaaS manager. 

* ``hypervisor-1``: runs *nova-compute*

* ``hypervisor-2``: runs *nova-compute*

However, due to limitation on the number of public IPs we have
available on the testbed, we will create one single VM with a floating
IP and will use this to forward the manage the OpenStack VMs and to
forward traffic destinated to the API to the correct VM.

Preparing the virtual machines
------------------------------

Open the browser at http://cloud-test.s3it.uzh.ch/horizon and login using one
of the very secret login/password we gave you. Each one of you will
have a project on its own, called `projectNN` and an user belonging to
that project, called `userNN`. The teacher will use `user01` and
`project01`.

The next step is to create the networks we will need, and start the
virtual machines.

In order, you will need to:

* import a keypair, needed to access the virtual machines via ssh

* create an `internal` network for your VMs.

* create a router, with gateway to `uzh-public` network

* add an interface to `internal` to your router

* ensure the default security groups allow you to access via ssh

* start the following virtual machines, using the image
  `ubuntu-trusty`:

  * `db-node`

  * `auth-node`

  * `image-node`

  * `compute-node`

  * `volume-node`

  * `network-node`
    
  * `hypervisor-1
    
  * `hypervisor-2`
    
The image `ubuntu-trusty` is a bare Ubuntu 14.04.3, so we will have to
install everything from scrach.


Start the Virtual Machines
--------------------------

You can create the virtual machines either via web interface or, if
you install on your laptop the following packages, also from the
command line:

* python-novaclient
* python-keystoneclient
* python-cinderclient
* python-neutronclient
* python-glanceclient

Create the networks
-------------------
First of all create a network which will simualte the "public" network in real world scenario::

   neutron net-create openstack-public

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

   neutron subnet-create openstack-public 10.0.0.0/24 --name openstack-public-subnet --allocation-pool start=10.0.0.3,end=10.0.0.254 --enable-dhcp --gateway 10.0.0.1 
   
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
  
    neutron router-create openstack-public-to-uzh-public

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

    neutron router-interface-add openstack-public-to-uzh-public openstack-public-subnet
    Added interface 38f22ccf-88cd-4a4f-8719-82caad291b60 to router openstack-public-to-uzh-public.

Set the router to act as a gateway for the uzh-public network::

    neutron router-gateway-set openstack-public-to-uzh-public uzh-public
    Set gateway for router openstack-public-to-uzh-public

Now we go on with creating the network which will simulate the private network of the OpenStack installation::

     neutron net-create openstack-priv
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

     neutron subnet-create openstack-priv 192.168.1.0/24 --name openstack-priv-subnet --dns-nameserver "130.60.128.3" --dns-nameserver "130.60.64.51" --allocation-pool start=192.168.1.3,end=192.168.1.254 --enable-dhcp --no-gateway
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

Once the VM is up and running take note of the IP assigned on the openstack-priv network and change the openstack-priv network to use that IP as a gateway::                  
   neutron subnet-update openstack-priv-subnet --host-route destination=0.0.0.0/0,nexthop=<IP_OF_THE_BASTION_ON_THE_PRIV_NETWORK>

Next step is disabling the security constrains Neutron is a applying in order to avoid arp spoofing. In our case this optsion will prevent MASQUERADING to work properly. In order to do this you have to find the port used from the bastion host on the openstack-priv network::

   neutron port-list | grep <IP_OF_THE_BASTION_ON_THE_PRIV_NETWORK>
   ede0a89a-4830-4780-a290-50c9cfd806a7 |      | fa:16:3e:18:93:cb | {"subnet_id": "c942c430-f819-4832-84a3-99da71323770", "ip_address": "<IP>"}

Disable the security groups and port security on that port::

   neutron port-update --no-security-groups --port-security-enabled=False ede0a89a-4830-4780-a290-50c9cfd806a7

..    
    There is a problem with this option since Neutron is blocking the forwared connections. 
    Chain neutron-openvswi-s25c99e62-6 (1 references)
    pkts bytes target     prot opt in     out     source               destination         
    2159  176K RETURN     all  --  any    any     192.168.1.10         anywhere             MAC FA:16:3E:20:FC:5C /* Allow traffic from defined IP/MAC pairs. */
    2919  245K DROP       all  --  any    any     anywhere             anywhere             /* Drop traffic without an IP/MAC allow rule. */
    We fixed this by adding xtension_drivers = port_security in /etc/neutron/plugins/ml2/ml2_conf.ini. This will create the relative entry in the database so next time network is created the "port_security_enabled" filed will be available and operations over it will be grated 

When done with this go on with assigning a floating IP on uzh-public network (can be done using the GUI)

Login to the bastion VM and configure the masquerading::

   root@bastion:~# dhclient eth1
   root@bastion:~# iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   root@bastion:~# iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
   root@bastion:~# iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
   root@bastion:~# echo 1 > /proc/sys/net/ipv4/ip_forward

You can persist those changes using iptables-save (part of the iptables-persistent debian package) and by setting "net.ipv4.ip_forward=1" in /etc/sysctl.conf. 

Assuming you already created the networks::

    (cloud)(cred:tutorial)antonio@kenny:~$ nova net-list
    +--------------------------------------+-------------+------+
    | ID                                   | Label       | CIDR |
    +--------------------------------------+-------------+------+
    | 890bbbf3-8fcd-40e4-b0b3-c2a4c9c52e35 | internal    | None |
    +--------------------------------------+-------------+------+

and you have a keypair named `antonio`, you can start the `db-node`
with the following command::

    (cloud)(cred:tutorial)antonio@kenny:~$ nova boot --key-name antonio --image ubuntu-14.04-cloudarchive --flavor m1.tiny --nic net-id=8cf2499c-4d99-4623-a482-a762bacd862d --nic net-id=890bbbf3-8fcd-40e4-b0b3-c2a4c9c52e35   db-node
    +--------------------------------------+------------------------------------------------------------------+
    | Property                             | Value                                                            |
    +--------------------------------------+------------------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                                           |
    | OS-EXT-AZ:availability_zone          | nova                                                             |
    | OS-EXT-STS:power_state               | 0                                                                |
    | OS-EXT-STS:task_state                | scheduling                                                       |
    | OS-EXT-STS:vm_state                  | building                                                         |
    | OS-SRV-USG:launched_at               | -                                                                |
    | OS-SRV-USG:terminated_at             | -                                                                |
    | accessIPv4                           |                                                                  |
    | accessIPv6                           |                                                                  |
    | adminPass                            | 82sRSviCiR5u                                                     |
    | config_drive                         |                                                                  |
    | created                              | 2015-05-02T09:32:56Z                                             |
    | flavor                               | m1.tiny (78342c00-6290-461e-8e56-357b59fbcf19)                   |
    | hostId                               |                                                                  |
    | id                                   | ebc906d3-cafb-4480-b165-8b35ae4774a0                             |
    | image                                | ubuntu-14.04-cloudarchive (33805688-f142-4dc4-9865-6f4197bbd8ad) |
    | key_name                             | antonio                                                          |
    | metadata                             | {}                                                               |
    | name                                 | db-node                                                          |
    | os-extended-volumes:volumes_attached | []                                                               |
    | progress                             | 0                                                                |
    | security_groups                      | default                                                          |
    | status                               | BUILD                                                            |
    | tenant_id                            | 3b8231f6ab974adbbcd838042bbf63bd                                 |
    | updated                              | 2015-05-02T09:32:56Z                                             |
    | user_id                              | anmess                                                           |
    +--------------------------------------+------------------------------------------------------------------+


Access the Virtual Machines
---------------------------

If you setup the keypair properly, and you started the virtual machine
with that keypair, you can login on the virtual machine using the IP
address given in `vlan842` network.

You can see the IP address of the VM via web interface or using `nova`
command::

    (cloud)(cred:tutorial)antonio@kenny:~$ nova list
    +--------------------------------------+---------+--------+------------+-------------+------------------------------------------+
    | ID                                   | Name    | Status | Task State | Power State | Networks                                 |
    +--------------------------------------+---------+--------+------------+-------------+------------------------------------------+
    | ebc906d3-cafb-4480-b165-8b35ae4774a0 | db-node | ACTIVE | -          | Running     | internal=10.0.0.13; vlan842=172.23.4.169 |
    +--------------------------------------+---------+--------+------------+-------------+------------------------------------------+

you should be able to connect either using regular user `gc3-user` or
as `root`::

    (cloud)(cred:tutorial)antonio@kenny:~$ ssh root@172.23.4.169
    Warning: Permanently added '172.23.4.169' (ECDSA) to the list of known hosts.
    Welcome to Ubuntu 14.04.2 LTS (GNU/Linux 3.13.0-32-generic x86_64)

     * Documentation:  https://help.ubuntu.com/
    root@db-node:~# 


Network Setup
-------------

**IMPORTANT NOTE**: each virtual machine has an interface in
`vlan842`. This is the only OpenStack network that is connected to a
*real* network, and thus is the only network we can use to connect to
the virtual machines. 

It is also the network we will use as `public` network (for floating
IPs, and to give access to the VMs we will create on `hypervisor-1` and
`hypervisor-2`).

In a real-world installation, only the nodes facing the internet will
have an interface on a public network. Specifically:

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


This is the list of networks we will use:

+------+-----------------------+-------------------------------------------------+
| iface| network               | IP range                                        |
+======+=======================+=================================================+
| eth0 | vlan842               | 172.23.0.0/16 for VMs, automatically assigned   |
|      |                       | range 172.23.99.0/24 used for floating IPs      |
+------+-----------------------+-------------------------------------------------+
| eth1 | internal network      | 10.0.0.0/24                                     |
+------+-----------------------+-------------------------------------------------+


The *vlan842* is the network exposed to the UZH network. We will use
it to access the VMs, that always have an IP in range
172.23.4.0-172.23.10.254, automatically assigned by the `cloud-test`
OpenStack, and on the network node we will also use the range
172.23.99.0/24 for floating IPs that will be assigned to the VMs we
create in your test cloud.

The *internal network* is a trusted network used by all the OpenStack
services to communicate to each other. Usually, you wouldn't setup a
strict firewall on this ip address.

The *OpenStack private network* is the internal network of the
OpenStack virtual machines. The virtual machines need to communicate
with the network node, (unless a "multinode setup is used") and among
them, therefore this network is configured only on the network node
(that also need to have an IP address in it) and the compute nodes,
which only need to have an interface on this network attached to a
bridge the virtual machines will be attached to. On a production
environment you would probably use a separated L2 network for this,
either by using VLANs or using a second physical interface. This is
why in this tutorial we have added a second interface to the compute
nodes, that will be used for VM-VM communication and to communicate
with the network node.

The following diagram shows both the network layout of the physical
machines and of the virtual machines running in it:

.. image:: ../images/network_diagram.png

Since we are using DHCP for both external network `vlan842` and the
`internal` networks, you should configure the ``/etc/hosts`` file on
all of your virtual machines in order to be able to connect to them
using only the hostname.

After you started all of your virtual machines, you could do something
like::

    (cloud)(cred:tutorial)antonio@kenny:~$ IPS=$(nova list --fields name,networks | grep vlan842|sed 's/.*vlan842=\(172.23.[0-9]\+\.[0-9]\+\).*/\1/g')
    (cloud)(cred:tutorial)antonio@kenny:~$ for ip in $IPS; do echo "$ip $(ssh  root@${ip} hostname).example.org" >> /tmp/hosts; done
    (cloud)(cred:tutorial)antonio@kenny:~$ for ip in $IPS; do priv=$(ssh root@$ip 'ifconfig eth1 | grep "inet addr" | sed "s/.*addr:\(10.0.0.[0-9]\+\).*/\1/g"'); host=$(ssh root@$ip hostname); echo "$priv $host" >> /tmp/hosts; done

Then, add this file to ``/etc/hosts`` on all the machines::

    (cloud)(cred:tutorial)antonio@kenny:~$ for ip in $IPS; do cat /tmp/hosts | ssh root@$ip 'cat >> /etc/hosts'; done


..
   Installation:
   -------------

   We will install the following services in sequence, on different
   virtual machines.

   * ``all nodes installation``: Common tasks for all the nodes
   * ``db-node``: MySQL + RabbitMQ,
   * ``auth-node``: keystone,
   * ``image-node``: glance,
   * ``compute-node``: nova-api, nova-scheduler,
   * ``network-node``: nova-network,
   * ``volume-node``: cinder,
   * ``hypervisor-1``: nova-compute,
   * ``hypervisor-2``: nova-compute,

