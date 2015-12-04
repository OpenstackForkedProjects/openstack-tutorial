---------------------------------------------
life of a VM (Compute service) - nova-compute
---------------------------------------------

As we did for the network node before staring it is good to quickly
check if the remote ssh execution of the commands done in the `all
nodes installation <basic_services.rst#all-nodes-installation>`_
section worked without problems. You can again verify it by checking
the ntp installation.

Nova-compute
------------

In the next few rows we try to briefly explain what happens behind the scene when a new request 
for starting an OpenStack instance is done. Note that this is very high level description. 

1) Authentication is performed either by the web interface **horizon**
   or **nova** command line tool:

   a) keystone is contacted and authentication is performed
   b) a *token* is saved in the database and returned to the client
      (horizon or nova cli) to be used with later interactions with
      OpenStack services for this request.

2) **nova-api** is contacted and a new request is created:

   a) it checks via *keystone* the validity of the token
   b) checks the authorization of the user
   c) validates parameters and create a new request in the database
   d) calls the scheduler via queue

3) **nova-scheduler** find an appropriate host

   a) reads the request
   b) find an appropriate host via filtering and weighting
   c) calls the choosen *nova-compute* host via queue

4) **nova-compute** read the request and start an instance:

   a) generates a proper configuration for the hypervisor 
   b) get image URI via image id
   c) download the image
   d) request to allocate network via queue

5) **nova-compute** requests creation of a neutron *port*

6) **neutron** allocate the port:

   a) allocates a valid private ip
   b) instructs the plugin agent to implement the port and wire it to
      the network interface to the VM [#]_

7) **nova-api** contacts *cinder* to provision the volume

   a) gets connection parameters from cinder
   b) uses iscsi to make the volume available on the local machine
   c) asks the hypervisor to provision the local volume as virtual
      volume of the specified virtual machine

8) **horizon** or **nova** poll the status of the request by
   contacting **nova-api** until it is ready.


Software installation
---------------------

Since our compute nodes support *nested virtualization* we can install
**kvm**::

    root@hypervisor-1:~# apt-get install -y nova-compute-kvm sysfsutils 

This will also install the **nova-compute-kvm** package and all its dependencies.

.. ANTONIO: not needed since nova-conductor is used for nova.
.. Not sure if the plugin agent needs it but I doubt it.

.. In order to allow the compute nodes to access the MySQL server you
.. must install the **MySQL python library**::

..    root@hypervisor-1:~# apt-get install -y python-mysqldb

nova configuration
------------------

The **nova-compute** daemon must be able to connect to the RabbitMQ and MySQL servers. 
The minimum information you have to provide in the ``/etc/nova/nova.conf`` file are::

    [DEFAULT]
    #...
    rpc_backend = rabbit
    auth_strategy = keystone
    my_ip = <IP_OF_THE_HYPERVISOR_HOST>
    
    [oslo_messaging_rabbit] 
    rabbit_host = db-node
    rabbit_userid = openstack
    rabbit_password = openstack 

    [oslo_concurrency]
    lock_path = /var/lib/nova/tmp
    
    [glance]
    host = image-node
        
    [vnc]
    enabled = True
    vncserver_listen = 0.0.0.0
    vncserver_proxyclient_address = <IP_OF_THE_HYPERVISOR_HOST>
    novncproxy_base_url = http://<PUBLIC_IP_BASTION>:6080/vnc_auto.html 

    [keystone_authtoken]
    auth_uri = http://auth-node:5000
    auth_url = http://auth-node:35357
    auth_plugin = password
    project_domain_id = default
    user_domain_id = default
    project_name = service
    username = nova
    password = openstack

.. WARNING: novncproxy_base_url should have the public ip, not the
   private one.    

..
    # Cinder
    cinder_catalog_info = volume:cinder:internalURL
    # This option has to be set, otherwise cinder
    # will try to use the publicURL (by default) which will
    # generate a "ConnectionError" message because
    # compute hosts have no public interface. 
    # Lets leave this as an exercise for the students.   

You can just replace the ``/etc/nova/nova.conf`` file with the content displayed above.

Check if the ``virt_type`` inside the ``[libvirt]`` of the ``/etc/nova/nova-compute.conf``
is set to ``kvm``.

neutron on the hypervisor
-------------------------

Install the needed components::

   root@hypervisor-1:~# apt-get install -y neutron-plugin-openvswitch-agent

To enable neutron for the nova-compute service you also have to ensure
the following lines to are presents in ``/etc/nova/nova.conf``::

    [DEFAULT]
    # ...
    network_api_class = nova.network.neutronv2.api.API
    linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
    firewall_driver = nova.virt.firewall.NoopFirewallDriver
    security_group_api = neutron

    [neutron]
    url = http://network-node:9696
    auth_url = http://auth-node:35357/
    auth_plugin = password
    project_name = service
    username = neutron
    password = openstack
    user_domain_id = default
    project_domain_id = default

Ensure the `br-int` bridge has been created by the installer::

    root@hypervisor-1:~# ovs-vsctl show
    8c5958c3-95a6-4929-8a84-0fbc7388a29b
        Bridge br-int
            fail_mode: secure
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.4.0"

Ensure `rp_filter` is disabled. As we did before, you need to ensure
the following lines are present in ``/etc/sysctl.conf`` file.

This file is read during the startup, but it is not read
afterwards. To force Linux to re-read the file you can run::

    root@hypervisor-1:~# sysctl -p /etc/sysctl.conf
    net.ipv4.conf.all.rp_filter=0
    net.ipv4.conf.default.rp_filter=0

Configure RabbitMQ and Keystone for neutron, by finding and editing the following 
options in the ``/etc/neutron/neutron.conf`` file::

    [DEFAULT]
    # ...
    rpc_backend = rabbit
    auth_strategy = keystone
    
    [oslo_messaging_rabbit]
    rabbit_host = db-node
    rabbit_userid = openstack
    rabbit_password = openstack

    [keystone_authtoken]
    auth_url = http://auth-node:5000
    auth_uri = http://auth-node:35357
    auth_plugin = password
    project_domain_id = default
    user_domain_id = default
    project_name = service
    username = neutron
    password = openstack

The ML2 plugin is configured in
``/etc/neutron/plugins/ml2/ml2_conf.ini``::

    [ml2]
    # ...
    type_drivers = gre
    tenant_network_types = gre
    mechanism_drivers = openvswitch
    	
    [ml2_type_gre]
    # ...
    tunnel_id_ranges = 1:1000

and in OVS plugin configuration
``/etc/neutron/plugins/ml2/openvswitch_agent.ini``::

    [ovs]
    # ...
    local_ip = <PRIVATE_IP_OF_COMPUTE_NODE>
    tunnel_type = gre
    enable_tunneling = True
    
    [agent]	
    tunnel_types = gre
    	
    [securitygroup]
    # ...
    firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
    enable_security_group = True

Restart `nova-compute` and the neutron agent::

    root@hypervisor-1:~# service nova-compute restart
    nova-compute stop/waiting
    nova-compute start/running, process 17740

    root@hypervisor-1:~# service neutron-plugin-openvswitch-agent restart
    neutron-plugin-openvswitch-agent stop/waiting
    neutron-plugin-openvswitch-agent start/running, process 17788

..
  Not needed:

   * Edit the qemu.conf with the needed options as specified in the tutorial (uncomment cgrout, ... )
   * Edit libvirt.conf (follow the tutorial)
   * Edit libvirt-bin.conf (follow the tutorial)
   * Modify l'API in api-paste.ini in order to abilitate access to keystone.

..
   When Nova is using the libvirt virtualization driver, the SMBIOS serial number
   supplied by libvirt is provided to the guest instances that are running on a
   compute node. This serial number may expose sensitive information about the
   underlying compute node hardware; it is preferrable to use the /etc/machine-id
   UUID instead of the host hardware UUID. This means that even containers will see
   a separate /etc/machine-id value.
   
   By default, the data source used to the populate the host "serial" UUID exposed
   to guest in the virtual BIOS is the file /etc/machine-id, falling back to the
   libvirt reported host UUID. If your compute node does not contain a valid
   /etc/machine-id file, generate one with the following command:
   
       root@hypervisor-1:~# uuidgen > /etc/machine-id
   
   For further details: https://wiki.openstack.org/wiki/OSSN/OSSN-0028

Final check
-----------

After restarting the **nova-compute** service::

    root@hypervisor-1 # service nova-compute restart

you should be able to see the compute node from the **your laptop** using the **inner** 
cloud credentials::

    user@ubuntu:~$ nova service-list
    +----+------------------+--------------+----------+---------+-------+----------------------------+-----------------+
    | Id | Binary           | Host         | Zone     | Status  | State | Updated_at                 | Disabled Reason |
    +----+------------------+--------------+----------+---------+-------+----------------------------+-----------------+
    | 1  | nova-conductor   | compute-node | internal | enabled | up    | 2015-11-30T09:53:10.000000 | -               |
    | 2  | nova-scheduler   | compute-node | internal | enabled | up    | 2015-11-30T09:53:10.000000 | -               |
    | 3  | nova-consoleauth | compute-node | internal | enabled | up    | 2015-11-30T09:53:12.000000 | -               |
    | 4  | nova-cert        | compute-node | internal | enabled | up    | 2015-11-30T09:53:08.000000 | -               |
    | 5  | nova-compute     | hypervisor-1 | nova     | enabled | up    | 2015-11-30T09:53:05.000000 | -               |
    +----+------------------+--------------+----------+---------+-------+----------------------------+-----------------+

You should also see the openvswitch agent from the output of `neutron agent-list`::

    root@compute-node:~# neutron agent-list
    +--------------------------------------+--------------------+--------------+-------+----------------+---------------------------+
    | id                                   | agent_type         | host         | alive | admin_state_up | binary                    |
    +--------------------------------------+--------------------+--------------+-------+----------------+---------------------------+
    | 1f19ea81-989f-4809-81e5-e1fb13449563 | L3 agent           | network-node | :-)   | True           | neutron-l3-agent          |
    | 48dfc51e-6523-419f-b382-5d9c1a838f86 | Metadata agent     | network-node | :-)   | True           | neutron-metadata-agent    |
    | 4d36ba37-97d7-4744-a3bb-1ba3ecbf0a94 | Open vSwitch agent | hypervisor-1 | :-)   | True           | neutron-openvswitch-agent |
    | 98598cc0-9ce0-4409-a7a6-3c66a74a14c9 | Open vSwitch agent | network-node | :-)   | True           | neutron-openvswitch-agent |
    | a02ead0d-2feb-4167-bde5-2324772d8011 | DHCP agent         | network-node | :-)   | True           | neutron-dhcp-agent        |
    +--------------------------------------+--------------------+--------------+-------+----------------+---------------------------+

Testing OpenStack
-----------------

We will test OpenStack first from **your latop** using the command line interface.

Creating a keypair
++++++++++++++++++

The first thing we need to do is to upload the public key of your 
keypair on the OpenStack so that we can connect to the instance::

    user@ubuntu:~$ nova keypair-add cscs-tutorial --pub-key ~/.ssh/id_rsa.pub

you can check that the keypair has been created with::

    user@ubuntu:~$ nova keypair-list
    +---------------+-------------------------------------------------+
    | Name          | Fingerprint                                     |
    +---------------+-------------------------------------------------+
    | cscs-tutorial | 46:12:e1:e1:95:e4:52:94:22:d9:a8:c0:f3:38:11:30 |
    +---------------+-------------------------------------------------+

Images, flavours, security groups
+++++++++++++++++++++++++++++++++

Let's get the ID of the available images, flavors and security groups::

    user@ubuntu:~$ nova image-list
    +--------------------------------------+--------------+--------+--------+
    | ID                                   | Name         | Status | Server |
    +--------------------------------------+--------------+--------+--------+
    | 79af6953-6bde-463d-8c02-f10aca227ef4 | cirros-0.3.3 | ACTIVE |        |
    +--------------------------------------+--------------+--------+--------+

    user@ubuntu:~$ nova flavor-list
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
    | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
    | 1  | m1.tiny   | 512       | 1    | 0         |      | 1     | 1.0         | True      |
    | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      |
    | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      |
    | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      |
    | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+

    user@ubuntu:~$ nova secgroup-list
    nova secgroup-list
    +--------------------------------------+---------+------------------------+
    | Id                                   | Name    | Description            |
    +--------------------------------------+---------+------------------------+
    | c24cfeb3-b32b-438c-8730-e6b86c713476 | default | Default security group |
    +--------------------------------------+---------+------------------------+
    
    user@ubuntu:~$ nova secgroup-list-rules c24cfeb3-b32b-438c-8730-e6b86c713476
    +-------------+-----------+---------+----------+--------------+
    | IP Protocol | From Port | To Port | IP Range | Source Group |
    +-------------+-----------+---------+----------+--------------+
    |             |           |         |          | default      |
    |             |           |         |          | default      |
    +-------------+-----------+---------+----------+--------------+

As you can see no traffic is allowed to the VM by default so we have to add at least the
possibility to ping and ssh the host:: 

    user@ubuntu:~$ nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    +-------------+-----------+---------+-----------+--------------+
    | IP Protocol | From Port | To Port | IP Range  | Source Group |
    +-------------+-----------+---------+-----------+--------------+
    | icmp        | -1        | -1      | 0.0.0.0/0 |              |
    +-------------+-----------+---------+-----------+--------------+

    user@ubuntu:~$ nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
    +-------------+-----------+---------+-----------+--------------+
    | IP Protocol | From Port | To Port | IP Range  | Source Group |
    +-------------+-----------+---------+-----------+--------------+
    | tcp         | 22        | 22      | 0.0.0.0/0 |              |
    +-------------+-----------+---------+-----------+--------------+

Starting an instance
++++++++++++++++++++

Now we are ready to start our first instance. We have to specify the network
the VM is going to use, so list the available networks first::

    user@ubuntu:~$ neutron net-list
    +--------------------------------------+----------+---------------------------------------------------+
    | id                                   | name     | subnets                                           |
    +--------------------------------------+----------+---------------------------------------------------+
    | 1116bfff-55e4-4b8d-bd6d-37e7d2eb26ae | demo-net | 44c2e4d7-21c2-461f-9270-b35de336fdb1 10.99.0.0/24 |
    | 4e733f65-3c10-4d2a-ad5b-dd73a3323dc5 | ext-net  | e4920247-3215-4593-9cf9-5670f6ed6363 10.0.0.0/24  |
    +--------------------------------------+----------+---------------------------------------------------+

Boot the instance then (using the net-id of the ``demo-net``)::

    user@ubuntu:~$ nova boot --image cirros-0.3.3 --security-group default \
    --flavor m1.tiny --key_name cscs-tutorial --nic net-id=1116bfff-55e4-4b8d-bd6d-37e7d2eb26ae server-1
    +--------------------------------------+-----------------------------------------------------+
    | Property                             | Value                                               |
    +--------------------------------------+-----------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                              |
    | OS-EXT-AZ:availability_zone          |                                                     |
    | OS-EXT-SRV-ATTR:host                 | -                                                   |
    | OS-EXT-SRV-ATTR:hypervisor_hostname  | -                                                   |
    | OS-EXT-SRV-ATTR:instance_name        | instance-00000004                                   |
    | OS-EXT-STS:power_state               | 0                                                   |
    | OS-EXT-STS:task_state                | scheduling                                          |
    | OS-EXT-STS:vm_state                  | building                                            |
    | OS-SRV-USG:launched_at               | -                                                   |
    | OS-SRV-USG:terminated_at             | -                                                   |
    | accessIPv4                           |                                                     |
    | accessIPv6                           |                                                     |
    | adminPass                            | jN7JdXVNwAQi                                        |
    | config_drive                         |                                                     |
    | created                              | 2015-11-30T10:21:58Z                                |
    | flavor                               | m1.tiny (1)                                         |
    | hostId                               |                                                     |
    | id                                   | ead1e0f2-03c3-42bf-8128-7699d99e2225                |
    | image                                | cirros-0.3.3 (b9bb6793-0e81-4127-84c2-0df7c7fbac1c) |
    | key_name                             | cscs-tutorial                                       |
    | metadata                             | {}                                                  |
    | name                                 | server-1                                            |
    | os-extended-volumes:volumes_attached | []                                                  |
    | progress                             | 0                                                   |
    | security_groups                      | default                                             |
    | status                               | BUILD                                               |
    | tenant_id                            | a05ccd509be642dda777782a231cc0eb                    |
    | updated                              | 2015-11-30T10:21:59Z                                |
    | user_id                              | cb050c0c0c8345f4802379477d0fba1a                    |
    +--------------------------------------+-----------------------------------------------------+

This command returns immediately::

    user@ubuntu:~$ nova list
    +--------------------------------------+----------+--------+------------+-------------+--------------------------------+
    | ID                                   | Name     | Status | Task State | Power State | Networks                       |
    +--------------------------------------+----------+--------+------------+-------------+--------------------------------+
    | ead1e0f2-03c3-42bf-8128-7699d99e2225 | server-1 | ACTIVE | -          | Running     | demo-net=10.99.0.5             |
    +--------------------------------------+----------+--------+------------+-------------+--------------------------------+

Assocsiating a floating IP
++++++++++++++++++++++++++

Next step is create and associate a floating IP to the instance so that we can connect from the laptops (over sshuttle)::

    user@ubuntu:~$ nova floating-ip-pool-list 
    +---------+
    | name    |
    +---------+
    | ext-net |
    +---------+
    
    user@ubuntu:~$ nova floating-ip-create ext-net
    +--------------------------------------+------------+-----------+----------+---------+
    | Id                                   | IP         | Server Id | Fixed IP | Pool    |
    +--------------------------------------+------------+-----------+----------+---------+
    | 661cb169-d913-421b-bcff-0433a348321c | 10.0.0.104 | -         | -        | ext-net |
    +--------------------------------------+------------+-----------+----------+---------+

Then at th end associate the IP to the server:: 

    user@ubuntu:~$ nova floating-ip-associate ead1e0f2-03c3-42bf-8128-7699d99e2225 10.0.0.104
    user@ubuntu:~$ nova list
    +--------------------------------------+----------+--------+------------+-------------+--------------------------------+
    | ID                                   | Name     | Status | Task State | Power State | Networks                       |
    +--------------------------------------+----------+--------+------------+-------------+--------------------------------+
    | ead1e0f2-03c3-42bf-8128-7699d99e2225 | server-1 | ACTIVE | -          | Running     | demo-net=10.99.0.5, 10.0.0.104 |
    +--------------------------------------+----------+--------+------------+-------------+--------------------------------+

When the instance is in ``ACTIVE`` state it means that it is now running on a compute node and 
you should be able to connect from you latop::

    user@ubuntu:~$ ssh 10.0.0.104 -lcirros
    The authenticity of host '10.0.0.104 (10.0.0.104)' can't be established.
    RSA key fingerprint is 63:58:64:ae:fb:cf:46:25:5d:8f:e9:b3:41:6c:0d:da.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '10.0.0.104' (RSA) to the list of known hosts.
    $ 

Testing cinder
++++++++++++++

You can attach a volume to a running instance easily::

    user@ubuntu:~$ nova volume-list
    nova volume-list
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | ID                                   | Status    | Display Name | Size | Volume Type | Attached to |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | 0ba76d55-4800-4c07-b5e2-e11c20df8e5b | available | 10           | 1    | -           |             |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+

    user@ubuntu:~$ nova volume-attach server-1 0ba76d55-4800-4c07-b5e2-e11c20df8e5b /dev/vdb
    +----------+--------------------------------------+
    | Property | Value                                |
    +----------+--------------------------------------+
    | device   | /dev/vdb                             |
    | id       | 0ba76d55-4800-4c07-b5e2-e11c20df8e5b |
    | serverId | ead1e0f2-03c3-42bf-8128-7699d99e2225 |
    | volumeId | 0ba76d55-4800-4c07-b5e2-e11c20df8e5b |
    +----------+--------------------------------------+

Inside the instnace, a new disk named ``/dev/vdb`` will appear. This disk is *persistent*, which means that if
you terminate the instance and then you attach the disk to a new instance, the content of the volume is persisted.

..
   Start a virtual machine using euca2ools
   +++++++++++++++++++++++++++++++++++++++
   
   The command is similar to ``nova boot``::
   
       root@compute-node:~# euca-run-instances \
         --access-key 445f486efe1a4eeea2c924d0252ff269 \
         --secret-key ff98e8529e2543aebf6f001c74d65b17 \
         -U http://compute-node.example.org:8773/services/Cloud \
         ami-00000001 -k gridka-compute-node
       RESERVATION	r-e9cq9p1o	acdbdb11d3334ed987869316d0039856	default
       INSTANCE	i-00000007	ami-00000001			pending	gridka-compute-node (acdbdb11d3334ed987869316d0039856, None)	0	m1.small	2013-08-29T07:55:15.000Z	nova				monitoring-disabled					instance-store	
   
   Instances created by euca2ools are, of course, visible with nova as
   well::
   
       root@compute-node:~# nova list
       +--------------------------------------+---------------------------------------------+--------+----------------------------+
       | ID                                   | Name                                        | Status | Networks                   |
       +--------------------------------------+---------------------------------------------+--------+----------------------------+
       | ec1e58e4-57f4-4429-8423-a44891a098e3 | Server ec1e58e4-57f4-4429-8423-a44891a098e3 | BUILD  | net1=10.99.0.3, 172.16.1.2 |
       +--------------------------------------+---------------------------------------------+--------+----------------------------+

Working with Flavors
--------------------

We have already seen, that there are a number of predefined flavors available
that provide certain classes of compute nodes and define number of vCPUs, RAM and disk.::

    user@ubuntu:~$ nova flavor-list
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public | extra_specs |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | 1  | m1.tiny   | 512       | 0    | 0         |      | 1     | 1.0         | True      | {}          |
    | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      | {}          |
    | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      | {}          |
    | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      | {}          |
    | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      | {}          |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+

In order to create a new flavor, use the CLI like so::

    user@ubuntu:~$ nova flavor-create --is-public true x1.tiny 6 256 2 1
    nova flavor-create --is-public true x1.tiny 6 256 2 1
    +----+---------+-----------+------+-----------+------+-------+-------------+-----------+
    | ID | Name    | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public |
    +----+---------+-----------+------+-----------+------+-------+-------------+-----------+
    | 6  | x1.tiny | 256       | 2    | 0         |      | 1     | 1.0         | True      |
    +----+---------+-----------+------+-----------+------+-------+-------------+-----------+

Where the parameters are like this::

    --is-public: controls if the image can be seen by all users
    --ephemeral: size of ephemeral disk in GB (default 0)
    --swap: size of swap in MB (default 0) 
    --rxtx-factor: network throughput factor (use to limit network usage) (default 1)
    x1.tiny:  the name of the flavor
    6:   the unique id of the flavor (check flavor list to see the next free flavor)
    256: Amount of RAM in MB
    2:   Size of disk in GB
    1:   Number of vCPUs

If we check the list again, we will see, that the flavor has been created::

    user@ubuntu:~$ nova flavor-list
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public | extra_specs |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | 1  | m1.tiny   | 512       | 0    | 0         |      | 1     | 1.0         | True      | {}          |
    | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      | {}          |
    | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      | {}          |
    | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      | {}          |
    | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      | {}          |
    | 6  | x1.tiny   | 256       | 2    | 0         |      | 1     | 1.0         | True      | {}          |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+

..  
   # Looks like resizing is not working on our setup, commenting out
   Change the flavor of an existing VM
   +++++++++++++++++++++++++++++++++++
   
   You can change the flavor of an existing VM (effectively resizing it) by running the following command.
   
   First lets find a running instance::
   
       user@ubuntu:~$ nova list 
       +--------------------------------------+----------+--------+------------+-------------+--------------------------------+
       | ID                                   | Name     | Status | Task State | Power State | Networks                       |
       +--------------------------------------+----------+--------+------------+-------------+--------------------------------+
       | ead1e0f2-03c3-42bf-8128-7699d99e2225 | server-1 | ACTIVE | -          | Running     | demo-net=10.99.0.5, 10.0.0.104 |
       +--------------------------------------+----------+--------+------------+-------------+--------------------------------+
   
   and see what flavor it has::
   
       user@ubuntu:~$ nova show ead1e0f2-03c3-42bf-8128-7699d99e2225 
       +--------------------------------------+----------------------------------------------------------+
       | Property                             | Value                                                    |
       +--------------------------------------+----------------------------------------------------------+
       | OS-DCF:diskConfig                    | MANUAL                                                   |
       | OS-EXT-AZ:availability_zone          | nova                                                     |
       | OS-EXT-SRV-ATTR:host                 | hypervisor-1                                             |
       | OS-EXT-SRV-ATTR:hypervisor_hostname  | hypervisor-1                                             |
       | OS-EXT-SRV-ATTR:instance_name        | instance-00000004                                        |
       | OS-EXT-STS:power_state               | 1                                                        |
       | OS-EXT-STS:task_state                | -                                                        |
       | OS-EXT-STS:vm_state                  | active                                                   |
       | OS-SRV-USG:launched_at               | 2015-11-30T10:22:05.000000                               |
       | OS-SRV-USG:terminated_at             | -                                                        |
       | accessIPv4                           |                                                          |
       | accessIPv6                           |                                                          |
       | config_drive                         |                                                          |
       | created                              | 2015-11-30T10:21:58Z                                     |
       | demo-net network                     | 10.99.0.5, 10.0.0.104                                    |
       | flavor                               | m1.tiny (1)                                              |
       | hostId                               | 5f0e703786a2ce08aaf53c580ad15d5f95c7cd8be7e866d6325f618d |
       | id                                   | ead1e0f2-03c3-42bf-8128-7699d99e2225                     |
       | image                                | cirros-0.3.3 (b9bb6793-0e81-4127-84c2-0df7c7fbac1c)      |
       | key_name                             | cscs-tutorial                                            |
       | metadata                             | {}                                                       |
       | name                                 | server-1                                                 |
       | os-extended-volumes:volumes_attached | [{"id": "0ba76d55-4800-4c07-b5e2-e11c20df8e5b"}]         |
       | progress                             | 0                                                        |
       | security_groups                      | default                                                  |
       | status                               | ACTIVE                                                   |
       | tenant_id                            | a05ccd509be642dda777782a231cc0eb                         |
       | updated                              | 2015-11-30T10:22:05Z                                     |
       | user_id                              | cb050c0c0c8345f4802379477d0fba1a                         |
       +--------------------------------------+----------------------------------------------------------+
   
   Now resisze the VM by specifying the new flavor ID::
   
       user@ubuntu:~$ nova resize ead1e0f2-03c3-42bf-8128-7699d99e2225 6
   
   While the server is resizing, its status will be RESIZING::
       
       root@compute-node:~# nova list --all-tenants
   
   Once the resize operation is done, the status will change to VERIFY_RESIZE and you will have to confirm
   that the resize operation worked::
   
       root@compute-node:~# nova resize-confirm bf619ff4-303a-417c-9631-d7147dd50585
   
   or, if things went wrong, revert the resize::
   
       root@compute-node:~# nova resize-revert bf619ff4-303a-417c-9631-d7147dd50585 
   
   The status of the server will now be back to ACTIVE.

.. BUGS
.. ----

.. * On Kilo-RC1, you have to write something in
..   ``/etc/machine-id``. Cfr. https://bugs.launchpad.net/ubuntu/+source/nova/+bug/1413293

References
----------
..

   We adapted the tutorial above with what we considered necessary for
   our purposes and for installing OpenStack on 6 hosts.

.. _`Openstack Compute Administration Guide`: http://docs.openstack.org/trunk/openstack-compute/admin/content/index.html



.. [#] how this is done, depends on the plugin and neutron
       configuration. In our setup, this means:
       1) create a linux bridge and attach it to the tap interface
       2) create a veth pair, attach one end to the bridge and the other to the `br-int` bridge
       3) set vlan tag for the port on the integration bridge
       4) configure *flows* on the integration bridge
       5) setup the L2 network (the gre tunnel) if it's not already there
       6) configure iptables (between the tap and the bridge interface) to enforce the security groups
       7) notify nova that the port is up and running
