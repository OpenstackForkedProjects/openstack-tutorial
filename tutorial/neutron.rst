-------------------------
Network service - neutron
-------------------------

db and keystone configuration
-----------------------------

neutron is more similar to cinder than to nova-network, so we will need to configure MySQL,
Keystone and rabbit like we did with all the other services.

First move to the **db-node** and create the database::

    root@db-node:~# mysql -u root -p
    
    MariaDB [(none)]> CREATE DATABASE neutron;
    MariaDB [(none)]> GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'openstack';
    MariaDB [(none)]> FLUSH PRIVILEGES;
    MariaDB [(none)]> exit

Create Neutron user, service and endpoint::

    user@ubuntu:~$ openstack user create --password openstack neutron
    +-----------+----------------------------------+
    | Field     | Value                            |
    +-----------+----------------------------------+
    | domain_id | default                          |
    | enabled   | True                             |
    | id        | 6a53d05e356e4c1e81bc200baa868c40 |
    | name      | neutron                          |
    +-----------+----------------------------------+
    
    user@ubuntu:~$ openstack role add --project service --user neutron admin
      
    user@ubuntu:~$ openstack service create --name neutron --description "OpenStack Networking" network
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | OpenStack Networking             |
    | enabled     | True                             |
    | id          | 16a5565a08364993994ef909c2ee0404 |
    | name        | neutron                          |
    | type        | network                          |
    +-------------+----------------------------------+

    user@ubuntu:~$ openstack endpoint create network \
      --region RegionOne \
      --publicurl http://<FLOATING_IP_BASTION>:9696 \
      --internalurl http://network-node:9696 \
      --adminurl http://<FLOATING_IP_BASTION>:9696
    +--------------+-----------------------------------+
    | Field        | Value                             |
    +--------------+-----------------------------------+
    | enabled      | True                              |
    | id           | 45bb5daa918b4eb2984573a17ec5b83f  |
    | interface    | internal                          |
    | region       | RegionOne                         |
    | region_id    | RegionOne                         |
    | service_id   | 16a5565a08364993994ef909c2ee0404  |
    | service_name | neutron                           |
    | service_type | network                           |
    | url          | http://<FLOATING_IP_BASTION>:9696 |
    +--------------+-----------------------------------+

``network-node`` configuration
------------------------------

and then ``eth1.cfg``::

    root@network-node:~# cat > /etc/network/interfaces.d/eth1.cfg <<EOF
    > auto eth1
    > iface eth1 inet static
    >   address 10.0.0.5
    >   netmask 255.255.255.0
    >   gateway 10.0.0.1
    > EOF

Neutron is composed of three different kind of services:

* neutron server (API)
* neutron plugin (to deal with different network types)
* neutron agent (some runs on the compute nodes, to provide
  integration between the hypervisor and networks set up by
  neutron. Others runs on a network node, to provide dhcp and routing
  capabilities)

We are going to install the neutron server and main plugins/agents on
the **network-node**, and the needed plugins on the compute
node.

Login on the **network-node** and install the following packages::

    root@network-node:~# apt-get install -y python-mysqldb neutron-server \
        neutron-dhcp-agent neutron-plugin-ml2 \
        neutron-plugin-openvswitch-agent neutron-l3-agent

On older releases you may need to also install
``openvswitch-datapath-dkms``, but on Ubuntu 14.04 is not needed.

The network node acts as gateway for the VMs, so we need to enable IP
forwarding. This is done by ensuring that the following lines is
present in ``/etc/sysctl.conf`` file::

    net.ipv4.ip_forward=1
    net.ipv4.conf.all.rp_filter=0
    net.ipv4.conf.default.rp_filter=0

This file is read during the startup, but it is not read
afterwards. To force Linux to re-read the file you can run::

    root@network-node:~# sysctl -p /etc/sysctl.conf
    net.ipv4.ip_forward = 1
    net.ipv4.conf.default.rp_filter = 0
    net.ipv4.conf.all.rp_filter = 0

The ``/etc/neutron/neutron.conf`` must be updated to reflect the
RabbitMQ, keystone and MySQL information::

    [DEFAULT]
    # ...
    rpc_backend = rabbit
    auth_strategy = keystone
     
    [oslo_messaging_rabbit]
    rabbit_host = db-node
    rabbit_userid = openstack
    rabbit_password = openstack 

    [keystone_authtoken]
    auth_uri = http://auth-node:5000
    auth_url = http://auth-node:35357
    auth_plugin = password
    project_domain_id = default
    user_domain_id = default
    project_name = service
    username = neutron
    password = openstack

    [database]
    connection = mysql://neutron:openstack@db-node/neutron


Then, we need to also update the configuration related to ML2, the
plugin we are going to use. Again in the
``/etc/neutron/neutron.conf``::

    [DEFAULT]
    # ...
    # ML2 configuration
    core_plugin = ml2
    service_plugins = router
    allow_overlapping_ips = True
    advertise_mtu = True

We also need to tell Neutron how to contact the `nova-api` service to
communicate any change in the network topology. Again in the
``/etc/neutron/neutron.conf`` file set::

    [DEFAULT]
    # ...
    notify_nova_on_port_status_changes = True
    notify_nova_on_port_data_changes = True
    nova_url = http://compute-node:8774/v2
    nova_admin_username = nova
    nova_admin_tenant_name = service 
    nova_admin_password = openstack
    nova_admin_auth_url = http://auth-node:5000/v2.0


The L3-agent (responsible for routing, using iptables) reads the
``/etc/neutron/l3_agent.ini`` file instead. Ensure the following
options are set::

    [DEFAULT]
    # ...
    interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver    
    use_namespaces = True
    external_network_bridge = br-eth1

.. by default external_network_bridge is `br-ex`

The DHCP agent (responsible for giving private IP addresses to the VMs
using DHCP protocol) reads file
``/etc/neutron/dhcp_agent.ini``. Ensure the following options are set::

    [DEFAULT]
    # ...
    interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver    
    dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
    use_namespaces = True
    dnsmasq_dns_servers = 130.60.128.3,130.60.64.51

The metadata agent works as the `nova-metadata-api` daemon we have
seen while configuring `nova-network`. It basically works as a
proxy, contacting the `nova-api` service and gives information about
the running VM.

As you know, when a VM starts it usually execute a program called
`cloud-init`, responsible to contact a well known web server (either
the default gateway or the 169.254.169.254 ip address) and asks for
information about the running instance, including keypairs, root
password, and/or extra data and programs to run (called `userdata`).

Metadata agent reads ``/etc/neutron/metadata_agent.init``
configuration file. Ensure the keystone information are correct, and
create a shared secret that will be shared between the `nova-api`
service and the `metadata-agent`::

    [DEFAULT]
    auth_url = http://auth-node:5000
    auth_region = RegionOne
    admin_tenant_name = service
    admin_user = neutron
    admin_password = openstack
    endpoint_type = internalURL
    # IP of the nova-api/nova-metadata-api service
    nova_metadata_ip = <IP_OF_THE_COMPUTE_NODE> 
    metadata_proxy_shared_secret = d1a6195d-5912-4ef9-b01f-426603d56bd2

The `metadata_proxy_shared_secret` must be the same string you put
in ``nova.conf``, option ``[neutron/metadata_proxy_shared_secret]``.



ML2 plugin configuration
------------------------

ML2 plugin must be configured to use OpenVSwitch to build virtual
networks. In this case we are using GRE tunnels to connect all the
various OpenVSwitch composing the virtual physical layer on top of
which Neutron will build its networks, so edit
``/etc/neutron/plugins/ml2/ml2_conf.ini`` and ensure the following
options are set::

    [ml2]
    #...
    type_drivers = gre,flat,vxlan
    tenant_network_types = gre
    mechanism_drivers = openvswitch

    [ml2_type_flat]
    #...
    flat_networks = public
        
    [ml2_type_gre]
    #...
    tunnel_id_ranges = 1:1000

    [securitygroup]
    #...
    enable_security_group = True
    enable_ipset = True

.. ANTONIO: Disabled port_security extension, this is only useful in
.. our outer cloud.
..     extension_drivers = port_security

In the ``/etc/neutron/plugins/ml2/openvswitch_agent.ini`` file set the 
OpenVSwitch options::

    [ovs]
    local_ip = <IP_OF_THE_NETWORK_NODE_ON_THE_PRIV_NETOWRK>
    bridge_mappings = public:br-eth1
    tunnel_type = gre
    enable_tunneling = True
    
    [agent]
    tunnel_types = gre

Database bootstrap
------------------

Initialize the database with::

    root@network-node:~# neutron-db-manage \
      --config-file /etc/neutron/neutron.conf \
      --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade liberty

 
OpenVSwitch
-----------

The package installer should have already created a `br-int` interface
(integration network), used to allow VM-to-VM communication::

   root@network-node:~# ovs-vsctl show 
   617b99d3-22a5-455d-9a54-d951b62dd9be
       Bridge br-int
           fail_mode: secure
           Port br-int
               Interface br-int
                   type: internal
       ovs_version: "2.4.0"

If NOT, create one with the following command::

    root@network-node:~# ovs-vsctl add-br br-int

The external bridge, however, is not automatically
configured. Moreover, neither the second interface has been ever
configured, as by default the standard Ubuntu image does not
automatically configure the second interface, so we have to do it
manually.

Also, if we just use dhcp to configure the second interface, we will
have two gateways defined, although the gateway of the network node
should be 10.0.0.1 (the neutron router of the **outer** cloud).

Let's fix this the proper way. First, we modify the configuration of
the eth0 interface, and we assign the IP statically. We will use the
same IPs assigned by Neutron, that are visible with the command::

    user@ubuntu:~$ nova interface-list network-node
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+
    | Port State | Port ID                              | Net ID                               | IP addresses | MAC Addr          |
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+
    | ACTIVE     | 7e79e74c-8d6c-4e22-bfc0-a793f110709a | 9a4ce8c1-950c-4432-86ef-a8ba4a9d0e28 | 10.0.0.5     | fa:16:3e:52:98:3c |
    | ACTIVE     | a7d2c2f8-129b-4f4f-949b-ad137bb1ca23 | dad2ca78-380e-48aa-8454-1218feb47947 | 192.168.1.12 | fa:16:3e:d8:da:f1 |
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+
    
To update the configuration of the eth0 interface we run::

    root@network-node:~# cat > /etc/network/interfaces.d/eth0.cfg  <<EOF
    > auto eth0
    > iface eth0 inet static
    >   address 192.168.1.12
    >   up ip route add 169.254.169.254/32 via 192.168.1.3 dev eth0
    >   netmask 255.255.255.0
    > EOF

We also need to set a route for the metadata server, pointing to the
address of the dhcp agent, to speedup the boot process.

Now we update the create a new file for `br-eth1`::

    root@network-node:~# cat > /etc/network/interfaces.d/br-eth1.cfg  <<EOF
    > allow-ovs br-eth1
    > iface br-eth1 inet manual
    >   ovs_type OVSBridge
    >   post-up ovs-vsctl --may-exist add-port br-eth1 eth1
    >   post-up ip link set dev eth1 up
    >   address 10.0.0.5
    >   netmask 255.255.255.0
    >   gateway 10.0.0.1
    >   dns-nameservers 130.60.128.3 130.60.64.51
    > EOF

Finally, we need to remove the port security also on the interface
corresponding to eth1, because when we attach eth1 to br-eth1 the MAC
address of the interface will change (the MAC of br-eth1 will be used
instead), and we need to force Neutron to remove any spoofing
protection it usually puts in place.

We know the port ID corresponding to eth1 from the previous ``nova
interface-list`` command, so::

    user@ubuntu:~$ neutron port-update \
      --port-security-enabled=False \
      --no-security-groups \
      7e79e74c-8d6c-4e22-bfc0-a793f110709a


At this point, a reboot of the server will be enough to configure both
interfaces correctly.

After the reboot, the openvswitch configuration should look like::

    root@network-node:~# ovs-vsctl show
    1a05c398-3024-493f-b3c4-a01912688ba4
        Bridge br-ex
            Port br-ex
                Interface br-ex
                    type: internal
            Port "eth0"
                Interface "eth0"
        Bridge br-int
            fail_mode: secure
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.0.1"

..
   Depending on your network interface driver, you may need to disable
   Generic Receive Offload (GRO) to achieve suitable throughput
   between your instances and the external network.

   To temporarily disable GRO on the external network interface while testing your environment:

   # ethtool -K INTERFACE_NAME gro off

..
   Please note that the network configuration of the neutron node should
   look like (also refer `troubleshooting session <troubleshooting1.rst>`_)::

       auto eth0
       iface eth0 inet static
           address 10.0.0.9
           netmask 255.255.255.0
           network 10.0.0.0
           broadcast 10.0.0.255

       auto eth1
       iface eth1 inet static
           address 172.16.0.9
           netmask 255.255.0.0
           broadcast 172.16.255.255
           gateway 172.16.0.1
           dns-nameservers 141.52.27.35
           dns-search example.org

..
   Also, the `eth0` interface, used by the `br-ex` bridge, must be UP
   and in promisc mode::

       root@network-node:~# ifconfig eth2 up promisc

   This can be done automatically at boot by editing
   ``/etc/network/interfaces``::

       auto eth0
       iface eth0 inet static
           address 0.0.0.0
           up ifconfig eth0 promisc

   Note that we don't assign any IP address, because this is done by
   neutron using virtual routers.

..
   Note: the following is only needed if you want to have the external
   interface _and_ the public interface on the same physical network!

   Configure the EXTERNAL_INTERFACE without an IP address and in
   promiscuous mode. Additionally, you must set the newly created br-ex
   interface to have the IP address that formerly belonged to
   EXTERNAL_INTERFACE.

   ``/etc/network/interfaces``::

       auto br-ex
       iface br-ex inet static
            address    172.16.0.9
            network    172.16.0.0
            netmask    255.255.0.0
            broadcast  172.16.255.255
            gateway    172.16.0.1
            up ifconfig eth2 promisc

   (didn't do anything on eth2 but remove IP and shut down the
   interfaces. Let's see what happen)



Default networks
----------------

**NOTE**: These instructions will not work, because security group on
the `cscs2015.gc3.uzh.ch` cloud will filter packets directed to the
floating IP of the VM!

Before starting any VM, we need to setup some basic networks.

In newtron, a `network` is a L2 network, very much like connecting
computers and switches using physical cables. On top of it, we create
one or more `subnet`, L3 network with a range IP assigned to them.

The first network we create is the *external* network, used by the VMs
of all the tenants to connect to the interned. As usual, you need to
setup the relevant environment variables (`OS_USERNAME`,
`OS_PASSWORD`, `OS_TENANT_NAME`, `OS_AUTH_URL`) in order to use the
`neutron` command::

    root@network-node:~# neutron net-create ext-net --router:external \
         --provider:physical_network external --provider:network_type flat
    Created a new network:
    +---------------------------+--------------------------------------+
    | Field                     | Value                                |
    +---------------------------+--------------------------------------+
    | admin_state_up            | True                                 |
    | id                        | b09f88f7-be98-40e1-9911-d1127182de96 |
    | name                      | external-net                         |
    | provider:network_type     | gre                                  |
    | provider:physical_network |                                      |
    | provider:segmentation_id  | 1                                    |
    | router:external           | True                                 |
    | shared                    | True                                 |
    | status                    | ACTIVE                               |
    | subnets                   |                                      |
    | tenant_id                 | cacb2edc36a343c4b4747b8a8349371a     |
    +---------------------------+--------------------------------------+

Let's now create the L3 network, using the range of floating IPs we
decided to use::

     root@network-node:~# neutron subnet-create ext-net --name ext-subnet \
     --allocation-pool start=10.0.0.100,end=10.0.0.200  --disable-dhcp \
     --gateway 10.0.0.1  10.0.0.0/24 
     +-------------------+----------------------------------------------+
     | Field             | Value                                        |
     +-------------------+----------------------------------------------+
     | allocation_pools  | {"start": "10.0.0.100", "end": "10.0.0.200"} |
     | cidr              | 10.0.0.0/24                                  |
     | dns_nameservers   |                                              |
     | enable_dhcp       | False                                        |
     | gateway_ip        | 10.0.0.1                                     |
     | host_routes       |                                              |
     | id                | e50aa1aa-3e9e-4072-8146-bdcd45214b46         |
     | ip_version        | 4                                            |
     | ipv6_address_mode |                                              |
     | ipv6_ra_mode      |                                              |
     | name              | ext-subnet                                   |
     | network_id        | 52a86e27-13d3-407f-af35-1560bd6134a4         |
     | subnetpool_id     |                                              |
     | tenant_id         | 3aab8a31a7124de690032b398a83db37             |
     +-------------------+----------------------------------------------+


The ``--disable-dhcp`` option is needed because on this network we
don't want to run a dhcp server.

Also, the ``--gateway`` option specify the *real* gateway of the
network (in our case, we set up the physical node to be the router for
the public network)

Now, we will create a network for a tenant. These commands *do not
need* to run as cloud administrator, they are supposed to be executed
by a regular user belonging to a tenant.

Moreover, the networks, subnetworks and routers we create now are only
visible and usable by the tenant, and they can have the same IP
addressing of other networks created by different tenants.

::
    
    root@network-node:~# neutron net-create demo-net
    Created a new network:
    +---------------------------+--------------------------------------+
    | Field                     | Value                                |
    +---------------------------+--------------------------------------+
    | admin_state_up            | True                                 |
    | id                        | 29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5 |
    | name                      | demo-net                             |
    | provider:network_type     | gre                                  |
    | provider:physical_network |                                      |
    | provider:segmentation_id  | 2                                    |
    | shared                    | False                                |
    | status                    | ACTIVE                               |
    | subnets                   |                                      |
    | tenant_id                 | cacb2edc36a343c4b4747b8a8349371a     |
    +---------------------------+--------------------------------------+
    
    root@network-node:~# neutron subnet-create demo-net --name demo --gateway 10.99.0.1 10.99.0.0/24
    Created a new subnet:
    +------------------+----------------------------------------------+
    | Field            | Value                                        |
    +------------------+----------------------------------------------+
    | allocation_pools | {"start": "10.99.0.2", "end": "10.99.0.254"} |
    | cidr             | 10.99.0.0/24                                 |
    | dns_nameservers  |                                              |
    | enable_dhcp      | True                                         |
    | gateway_ip       | 10.99.0.1                                    |
    | host_routes      |                                              |
    | id               | 5d4c6c72-9cf8-4272-8cec-08bd04b4b1f4         |
    | ip_version       | 4                                            |
    | name             | demo-subnet                                  |
    | network_id       | 29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5         |
    | tenant_id        | cacb2edc36a343c4b4747b8a8349371a             |
    +------------------+----------------------------------------------+

This network is completely isolated, as it has no connection to the
external network we created before. In order to connect the two, we
need to create a router::

    root@network-node:~# neutron router-create demo-router
    Created a new router:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | external_gateway_info |                                      |
    | id                    | 3616bd03-0100-4247-9699-2839e360a688 |
    | name                  | demo-router                          |
    | status                | ACTIVE                               |
    | tenant_id             | cacb2edc36a343c4b4747b8a8349371a     |
    +-----------------------+--------------------------------------+

and connect it to the subnet `demo-subnet`::

    root@network-node:~# neutron router-interface-add demo-router demo-subnet
    Added interface 32ea1402-bb31-4575-8c14-06aea02d3442 to router demo-router.

and to the external network `external-net`::

    root@network-node:~# neutron router-gateway-set demo-router external-net
    Set gateway for router demo-router

On the neutron node, you should see that new ports have been created
on openvswitch::

    root@network-node:~# ovs-vsctl show
    1a05c398-3024-493f-b3c4-a01912688ba4
        Bridge br-ex
            Port br-ex
                Interface br-ex
                    type: internal
            Port "eth2"
                Interface "eth2"
            Port "qg-808b139c-45"
                Interface "qg-808b139c-45"
                    type: internal
        Bridge br-int
            fail_mode: secure
            Port "qr-32ea1402-bb"
                Interface "qr-32ea1402-bb"
                    type: internal
            Port patch-tun
                Interface patch-tun
                    type: patch
                    options: {peer=patch-int}
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.0.1"

and a new namespace has been created::

    root@network-node:~# ip netns list
    qrouter-3616bd03-0100-4247-9699-2839e360a688

In order to allow multiple tenant networks to share the same range of
IP addresses, neutron uses `namespaces`. This also means that the IP
address of the router `demo-router` is *not* visibile on the default
namespare, but only on the namespace created for that router. Indeed,
running `ip addr show`::

    root@network-node:~# ip addr show|grep 10.99
    root@network-node:~# 

will show no IP addresses on the range we specified in the default
namespace.

However, switching namespace...::

    root@network-node:~# ip netns exec qrouter-3616bd03-0100-4247-9699-2839e360a688 ip addr show
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
        inet6 ::1/128 scope host 
           valid_lft forever preferred_lft forever
    8: qr-1970dd4b-d2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
        link/ether fa:16:3e:ff:f1:1e brd ff:ff:ff:ff:ff:ff
        inet 10.99.0.1/24 brd 10.99.0.255 scope global qr-1970dd4b-d2
           valid_lft forever preferred_lft forever
        inet6 fe80::f816:3eff:feff:f11e/64 scope link 
           valid_lft forever preferred_lft forever
    9: qg-e53e4354-9f: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
        link/ether fa:16:3e:3a:36:81 brd ff:ff:ff:ff:ff:ff
        inet 10.0.0.100/24 brd 10.0.0.255 scope global qg-e53e4354-9f
           valid_lft forever preferred_lft forever
        inet6 fe80::f816:3eff:fe3a:3681/64 scope link 
           valid_lft forever preferred_lft forever

will show you the `10.99.0.1` ip address, that has been automatically
choosen for the `demo-router`.

Netspaces increase the flexibility but of course makes troubleshooting
much more complicated...

Now, as you can see::

    root@network-node:~# neutron port-list
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    | id                                   | name | mac_address       | fixed_ips                                                                         |
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    | 1970dd4b-d28c-47ab-b92b-5198a1f220ef |      | fa:16:3e:ff:f1:1e | {"subnet_id": "87b4b32d-f117-4839-860b-0c08a4d1c668", "ip_address": "10.99.0.1"}  |
    | 22900d40-8d75-4f46-b91e-11a974611155 |      | fa:16:3e:bd:8e:70 | {"subnet_id": "87b4b32d-f117-4839-860b-0c08a4d1c668", "ip_address": "10.99.0.2"}  |
    | e53e4354-9fc8-427a-81a6-5598df819f5e |      | fa:16:3e:3a:36:81 | {"subnet_id": "3254e750-4da1-4308-a97c-2381268c044c", "ip_address": "10.0.0.100"} |
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    root@network-node:~# neutron subnet-list
    +--------------------------------------+------------+--------------+----------------------------------------------+
    | id                                   | name       | cidr         | allocation_pools                             |
    +--------------------------------------+------------+--------------+----------------------------------------------+
    | 3254e750-4da1-4308-a97c-2381268c044c | ext-subnet | 10.0.0.0/24  | {"start": "10.0.0.100", "end": "10.0.0.200"} |
    | 87b4b32d-f117-4839-860b-0c08a4d1c668 | demo       | 10.99.0.0/24 | {"start": "10.99.0.2", "end": "10.99.0.254"} |
    +--------------------------------------+------------+--------------+----------------------------------------------+

an IP address has been assigned to the virtual port connected to the
`ext-subnet` subnetwork. This is only visible on the router namespace,
as you have already seen::

    root@network-node:~# ip netns exec qrouter-3616bd03-0100-4247-9699-2839e360a688 ip addr show | grep 10.0
        inet 10.0.0.100/24 brd 10.0.0.255 scope global qg-e53e4354-9f


You should be able to ping this IP from the bastion host::

    root@bastion:~# ping 10.0.0.100 -c 1
    PING 10.0.0.100 (10.0.0.100) 56(84) bytes of data.
    64 bytes from 10.0.0.100: icmp_seq=1 ttl=64 time=0.651 ms

    --- 10.0.0.100 ping statistics ---
    1 packets transmitted, 1 received, 0% packet loss, time 0ms
    rtt min/avg/max/mdev = 0.651/0.651/0.651/0.000 ms
    root@bastion:~# 

