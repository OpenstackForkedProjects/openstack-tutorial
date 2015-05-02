Tutorial overview
=================

During this tutorial, each one of you will have access to an OpenStack
private cloud and will create one instance per service:

* ``db-node``:  runs *MySQL* and *RabbitMQ*

* ``auth-node``: runs *keystone*, the identity and authentication
  service

* ``image-node``: runs **glance**, the image storage, composed of the
  *glance-api* and glance-registry* services

* ``api-node``: runs most of the **nova** service: *nova-api*,
  *horizon*, *nova-scheduler*, *nova-conductor* and *nova-console*.

* ``volume-node``: runs **cinder**, the volume manager, composed of
  the *cinder-api*, *cinder-scheduler* and *cinder-volume* services

* ``neutron-node``: runs **neutron**, the NaaS manager. 

* ``compute-1``: runs *nova-compute*

* ``compute-2``: runs *nova-compute*

Preparing the virtual machines
++++++++++++++++++++++++++++++

Open the browser at http://cloud-test.gc3.uzh.ch and login using your
UZH `WebPass` login and password. Each one of you will have a tenant
on its own.

The next step is to create the networks we will need, and start the
virtual machines.

In order, you will need to:

* import a keypair, needed to access the virtual machines via ssh

* create 2 networks:
  - `internal`: each node will talk to the internal services using
    this network.

* ensure the default security groups allow you to access via ssh

* start the following virtual machines, using the image
  `ubuntu-14.04-cloudarchive`:

  * `db-node`, networks:
    - vlan842
    - internal

  * `auth-node`, networks:
    - vlan842
    - internal

  * `image-node`, networks:
    - vlan842
    - internal

  * `api-node`, networks:
    - vlan842
    - internal

  * `volume-node`, networks:
    - vlan842
    - internal

  * `network-node`, networks:
    - vlan842
    - internal
    
  * `compute-1`, networks:
    - vlan842
    - internal
    
  * `compute-2`, networks:
    - vlan842
    - internal
    
The image `ubuntu-14.04-cloudarchive` is an Ubuntu 14.04.2
Ubuntu 14.04 with a few services already configured:

* ntp

* proxy

* repository for OpenStack Juno

Start the Virtual Machines
~~~~~~~~~~~~~~~~~~~~~~~~~~

You can create the virtual machines either via web interface or, if
you install on your laptop the following packages, also from the
command line:

* python-novaclient
* python-keystoneclient
* python-cinderclient
* python-neutronclient
* python-glanceclient

Assuming you already created the networks::

    (cloud)(cred:tutorial)antonio@kenny:~$ nova net-list
    +--------------------------------------+-------------+------+
    | ID                                   | Label       | CIDR |
    +--------------------------------------+-------------+------+
    | 890bbbf3-8fcd-40e4-b0b3-c2a4c9c52e35 | internal    | None |
    | 8cf2499c-4d99-4623-a482-a762bacd862d | vlan842     | None |
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
~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
+++++++++++++

**IMPORTANT NOTE**: each virtual machine has an interface in
`vlan842`. This is the only OpenStack network that is connected to a
*real* network, and thus is the only network we can use to connect to
the virtual machines. 

It is also the network we will use as `public` network (for floating
IPs, and to give access to the VMs we will create on `compute-1` and
`compute-2`).

In a real-world installation, only the nodes facing the internet will
have an interface on a public network. Specifically:

+--------------+---------------------------------+
| node         | service requiring public access |
+==============+=================================+
| api-node     | nova-api                        |
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


`Next: Installation of basic services <basic_services.rst>`_

..
   Installation:
   -------------

   We will install the following services in sequence, on different
   virtual machines.

   * ``all nodes installation``: Common tasks for all the nodes
   * ``db-node``: MySQL + RabbitMQ,
   * ``auth-node``: keystone,
   * ``image-node``: glance,
   * ``api-node``: nova-api, nova-scheduler,
   * ``network-node``: nova-network,
   * ``volume-node``: cinder,
   * ``compute-1``: nova-compute,
   * ``compute-2``: nova-compute,

