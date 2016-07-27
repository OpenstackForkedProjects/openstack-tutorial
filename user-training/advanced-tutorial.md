Advanced tutorial on ScienceCloud
=================================

This is a draft handout for an advanced tutorial on ScienceCloud.

The tutorial will cover some of the less known aspects of OpenStack
and specifically ScienceCloud.

A special ubuntu image will be used for the exercises of the tutorial,
with the correct software already installed and part of the needed
environment.


Table of Contents
=================

  * [Advanced tutorial on ScienceCloud](#advanced-tutorial-on-sciencecloud)
    * [advanced networking - basic concepts](#advanced-networking---basic-concepts)
      * [networks](#networks)
      * [subnet](#subnet)
      * [ports](#ports)
      * [router](#router)
      * [floating IPs](#floating-ips)
      * [dhcp](#dhcp)
      * [isolated networks](#isolated-networks)
      * [security groups](#security-groups)
      * [hosts with multiple interfaces](#hosts-with-multiple-interfaces)
    * [CLI](#cli)
      * [boot instance](#boot-instance)
      * [boot from volume](#boot-from-volume)
      * [attach volume](#attach-volume)
      * [boot instance using port-id and reuse existing port](#boot-instance-using-port-id-and-reuse-existing-port)
      * [security groups](#security-groups-1)
      * [userdata](#userdata)
      * [instance snapshot](#instance-snapshot)
      * [snapshot of a volume](#snapshot-of-a-volume)
      * [lock an instance](#lock-an-instance)
      * [shelve an instance](#shelve-an-instance)
      * [attach/detach an interface to a VM](#attachdetach-an-interface-to-a-vm)
    * [SWIFT (cli)](#swift-cli)
    * [Python API (shade)](#python-api-shade)


## advanced networking - basic concepts

### networks
  
A network is a layer 2 network. This can be implemented as a
virtual network or a physical network. Virtual (or tenant)
networks can only be used to connect VMs and cloud routers,
while a physical (provider) network can be used to talk to the
rest of the university network.

On SC there are two provider networks:
* uzh-only
* public

A regular user can only create tenant network, so when you want
to provide connectivity to a VM to the outside world you have to
either create a VM on the uzh-only network (since creating a VM
on the public network is not allowed), or you have to create a
tenant network connected via virtual router to a provider
network

To create a (tenant) network use:

    (cloud)(cred:training@sc)anmess@kenny:~$ neutron net-create privnet-1
    Created a new network:
    +-----------------+--------------------------------------+
    | Field           | Value                                |
    +-----------------+--------------------------------------+
    | admin_state_up  | True                                 |
    | id              | 33503f07-178b-4eda-87af-305308e80349 |
    | mtu             | 0                                    |
    | name            | privnet-1                            |
    | router:external | False                                |
    | shared          | False                                |
    | status          | ACTIVE                               |
    | subnets         |                                      |
    | tenant_id       | 92b952a1b50149a687f6b7c8f54eec4b     |
    +-----------------+--------------------------------------+

There isn't much else you can do with a simple network as non-admin of
the cloud.

### subnet

A subnet is a block of IPs associated to a network. It also
contains some configuration, for instance

* routed vs isolated network
* DHCP enabled or disabled
* static routes
* dns servers

To create a subnet you can:

    (cloud)(cred:training@sc)anmess@kenny:~$ neutron subnet-create privnet-1  10.11.22.0/24  --name privsubnet-1
    Created a new subnet:
    +-------------------+------------------------------------------------+
    | Field             | Value                                          |
    +-------------------+------------------------------------------------+
    | allocation_pools  | {"start": "10.11.22.2", "end": "10.11.22.254"} |
    | cidr              | 10.11.22.0/24                                  |
    | dns_nameservers   |                                                |
    | enable_dhcp       | True                                           |
    | gateway_ip        | 10.11.22.1                                     |
    | host_routes       |                                                |
    | id                | 661449ae-2fd3-4e0a-bc06-b7c312185030           |
    | ip_version        | 4                                              |
    | ipv6_address_mode |                                                |
    | ipv6_ra_mode      |                                                |
    | name              | privsubnet-1                                   |
    | network_id        | 33503f07-178b-4eda-87af-305308e80349           |
    | subnetpool_id     |                                                |
    | tenant_id         | 92b952a1b50149a687f6b7c8f54eec4b               |
    +-------------------+------------------------------------------------+


By default:

* DHCP is enabled. You can disable with `--disable-dhcp`
* the pool of IP addresses used for the VMs starts from with the third and ends
  with last IP of the network. You can define a different allocation
  pool with `--allocation-pool start=<START-IP>,end=<END-IP>`
* the dhcp server will act as DNS server. You can specify different DNS
  servers with optin `--dns-nameserver <DNS-IP>`.
* no extra routes are added. To pass a static route to the VM you can
  add `--host-route destination=CIDR,nexthop=IPADDR`


### ports

A port is a connection point for attaching a single
device, for instance the interface of a virtual machine, or the
interface of a router. It contains information on the IP and MAC
address. When you create a VM and specify the a network a port
is created automatically, but you can also create a port manually
and then start a VM (using the cli) specifying which port you
want to use.

### router

A router is a virtual router that allows two VMs on two
different networks to communicate. Optionally a router can be
attached to a provider network to allow communication with the
outside world. This is called "gateway" and only one per router
can be defined.

You can for instance have 3 tenant networks connected to the
same router, and allow traffic among all the VMs on those
networks.

When a router is connected to a provider network NAT is enabled
by default, so that a VM can access the provider network using
the IP of the virtual router. Optionally you can set a floating
IP: in this case the floating IP "lives" on the router, which
will provide 1:1 NAT to allow access to the VM from the provider
network.

### floating IPs

A floating IP is a special "port" on a provider network. When
you allocate a floating IP this is associated to your tenant and
never automatically disassociated. You can then associate this
floating IP to any VMs, assuming the VM is connected to a
network where the gateway is on the provider network of the
floating IP. For instance: assume you have:

* tenant network NET1 10.0.0.0/24
* VM1 in tenant network NET1
* router R1 on tenant network with gateway on uzh-only network
* floating IP FIP1 allocated from public network

in this case you cannot associate the floating IP FIP1 to VM1,
but you can allocate a floating IP FIP2 from uzh-only network
and associated it to VM1

### dhcp

DHCP is a protocol to automatically assign IP addresses to
hosts. When you create a subnet you can specify if dhcp is enabled
or not. You can also specify the range of public IPs to be used for
DHCP.

### isolated networks

An isolated network is a network without a gateway. This network
can only be connected to other tenant networks via router, but
cannot be used to access a provider network.

### security groups

security groups are group of firewall rules that are associated
to a port. By default security groups are associated to all the
interfaces of a VM, but with the CLI you can also associate a
security group to a single port.

You can dynamically associate or disassociate a security group
to a VM/port, and you can add or remove rules to/from a security
group at any time. Changes are applied "immediately" and do not
require a reboot of the VM

Since these rules are applied to the port *from the outside*,
they do not rely on any firewall software installed on the VM
image.

The default security group allow all outgoing traffic from the
VM and blocks all incoming traffic to the VM. SC default
security group already has two rules to allow ICMP and SSH
incoming traffic to the VM, but you can disable it. You can also
disable outgoing traffic by deleting the corresponding rules
from the default security group.
    
### hosts with multiple interfaces

You can always create VMs with multiple interfaces. However, most
images only configure the first interface, and the configuration
of a multi-homed host can be tricky, so be careful. In principle
you want to use the network you can access the VM from to the
first interface (for instance, uzh-only), then configure the other
interfaces manually from within the VM.

You can also add a second interface later on to the system. If you
do that, the VM will most probably leave the extra interface
unconfigured. This also means that if you start a VM without any
interface then if you attach a network interface after the VM
booted you will not be able to connect via ssh, but you will have
to connect to the console (assuming you know the password) and
configure the interface. We suggest to always create a VM with at
least one interface in a network accessible from the outside
(either uzh-only or a tenant network configured with floating IPs
on uzh-only or public) and then, if needed, add a second interface
to the VM.

## CLI

### boot instance

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack network list
    +--------------------------------------+----------+--------------------------------------+
    | ID                                   | Name     | Subnets                              |
    +--------------------------------------+----------+--------------------------------------+
    | 52c5c5a5-7a31-4e5e-b092-20c3fba7af0a | private  | 4892c55f-0f4b-4858-bd10-5c9dcb33135f |
    | c26621b2-10e2-443e-bac3-ad2fd17e41d7 | public   | 0687cbb6-3a37-4b4d-82ec-8c80badaadca |
    | c86b320c-9542-4032-a951-c8a068894cc2 | uzh-only | f9702c62-9245-471c-a7d0-0b1130d97d58 |
    +--------------------------------------+----------+--------------------------------------+
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack security group list
    +--------------------------------------+---------------------+-------------------------------------------+----------------------------------+
    | ID                                   | Name                | Description                               | Project                          |
    +--------------------------------------+---------------------+-------------------------------------------+----------------------------------+
    | 1e0846c8-070f-4e40-a244-2586a63546bf | hr_training_new_sec |                                           | 92b952a1b50149a687f6b7c8f54eec4b |
    | 313f543f-7ab1-4e73-b91e-aae41d6f6af1 | DinosaurCodes       |                                           | 92b952a1b50149a687f6b7c8f54eec4b |
    | 4d2e88bc-22db-4cb1-9ea9-396719465a51 | with_https          | SSH + HTTPS                               | 92b952a1b50149a687f6b7c8f54eec4b |
    | 6571749b-29e6-49fd-a449-837620612ccf | ethercalc           | default port for ethercalc service (8000) | 92b952a1b50149a687f6b7c8f54eec4b |
    | 726e61e0-abf0-40a6-9f97-06cd5b10f316 | Test_NW             |                                           | 92b952a1b50149a687f6b7c8f54eec4b |
    | 7d21134e-54a5-40ad-b3d3-eb1d6ac9c9ec | rdp                 |                                           | 92b952a1b50149a687f6b7c8f54eec4b |
    | 98383d04-9149-4ac7-96c8-8c8564484048 | Chemistry1          |                                           | 92b952a1b50149a687f6b7c8f54eec4b |
    | a013c90c-6429-455c-8638-5b558188bf2f | randomPORT          | specific sw                               | 92b952a1b50149a687f6b7c8f54eec4b |
    | fae6c332-05a6-4345-99b3-f348af1304e6 | default             | Default security group                    | 92b952a1b50149a687f6b7c8f54eec4b |
    +--------------------------------------+---------------------+-------------------------------------------+----------------------------------+
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack image list | grep Ubuntu.*14.04
    | 2b227d15-8f6a-42b0-b744-ede52ebe59f7 | Ubuntu Server 14.04.04 LTS (2016-05-19)               | active |
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack keypair list
    +---------------+-------------------------------------------------+
    | Name          | Fingerprint                                     |
    +---------------+-------------------------------------------------+
    | anmess_bemovi | 0d:f9:8d:b7:04:38:41:93:42:e4:3a:f1:f5:11:58:9a |
    | antonio       | 61:ba:f9:16:8e:33:05:e6:8a:bf:cb:95:1f:40:9a:a0 |
    | antonio_irm   | 68:d5:b5:a8:dd:99:8c:3d:87:f7:66:63:19:5e:47:bf |
    | antonio_rsa   | b4:5c:7c:67:92:b1:41:a0:34:e7:57:77:ff:f6:cc:ba |
    | sysadmins     | 46:12:e1:e1:95:e4:52:94:22:d9:a8:c0:f3:38:11:30 |
    +---------------+-------------------------------------------------+
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server create --nic net-id=c86b320c-9542-4032-a951-c8a068894cc2 --key-name antonio --flavor 1cpu-4ram-hpc --image 2b227d15-8f6a-42b0-b744-ede52ebe59f7 --security-group default anto-test
    +--------------------------------------+--------------------------------------------------------------------------------+
    | Field                                | Value                                                                          |
    +--------------------------------------+--------------------------------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                                                         |
    | OS-EXT-AZ:availability_zone          |                                                                                |
    | OS-EXT-STS:power_state               | NOSTATE                                                                        |
    | OS-EXT-STS:task_state                | scheduling                                                                     |
    | OS-EXT-STS:vm_state                  | building                                                                       |
    | OS-SRV-USG:launched_at               | None                                                                           |
    | OS-SRV-USG:terminated_at             | None                                                                           |
    | accessIPv4                           |                                                                                |
    | accessIPv6                           |                                                                                |
    | addresses                            |                                                                                |
    | adminPass                            | kwnAKBV74MDe                                                                   |
    | config_drive                         |                                                                                |
    | created                              | 2016-07-26T14:19:06Z                                                           |
    | flavor                               | 1cpu-4ram-hpc (48fdc4c7-c789-4891-a684-2969ef419ada)                           |
    | hostId                               |                                                                                |
    | id                                   | df9bdb86-7a12-4305-a612-48b1cb42ab05                                           |
    | image                                | Ubuntu Server 14.04.04 LTS (2016-05-19) (2b227d15-8f6a-42b0-b744-ede52ebe59f7) |
    | key_name                             | antonio                                                                        |
    | name                                 | anto-test                                                                      |
    | os-extended-volumes:volumes_attached | []                                                                             |
    | progress                             | 0                                                                              |
    | project_id                           | 92b952a1b50149a687f6b7c8f54eec4b                                               |
    | properties                           |                                                                                |
    | security_groups                      | [{u'name': u'default'}]                                                        |
    | status                               | BUILD                                                                          |
    | updated                              | 2016-07-26T14:19:06Z                                                           |
    | user_id                              | anmess                                                                         |
    +--------------------------------------+--------------------------------------------------------------------------------+

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server list
    +--------------------------------------+-----------+--------+------------------------+
    | ID                                   | Name      | Status | Networks               |
    +--------------------------------------+-----------+--------+------------------------+
    | df9bdb86-7a12-4305-a612-48b1cb42ab05 | anto-test | ACTIVE | uzh-only=172.23.51.238 |
    +--------------------------------------+-----------+--------+------------------------+

You can check the console log with:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack console log show anto-test
    [    0.000000] Initializing cgroup subsys cpuset
    [    0.000000] Initializing cgroup subsys cpu
    [    0.000000] Initializing cgroup subsys cpuacct
    [    0.000000] Linux version 3.13.0-86-generic (buildd@lgw01-51) (gcc version 4.8.2 (Ubuntu 4.8.2-19ubuntu1) ) #131-Ubuntu SMP Thu May 12 23:33:13 UTC 2016 (Ubuntu 3.13.0-86.131-generic 3.13.11-ckt39)
    [    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-3.13.0-86-generic root=LABEL=cloudimg-rootfs ro console=tty1 console=ttyS0
    [    0.000000] KERNEL supported cpus:
    [    0.000000]   Intel GenuineIntel
    [    0.000000]   AMD AuthenticAMD
    [    0.000000]   Centaur CentaurHauls
    [    0.000000] e820: BIOS-provided physical RAM map:


### boot from volume

Most of the VMs are *ephemeral*
(cfr. [Pet vs. Cattle](http://www.theregister.co.uk/2013/03/18/servers_pets_or_cattle_cern/)),
i.e the data stored on their filesystem is not important and can get
lost when the instance is terminated.

Sometimes however you will need to setup a *PET*, and you want to be
sure that even if the instance is terminated by mistake you don't lose
any data.

To do that, you need to create a volume (as volumes are persistent,
while root disk of VMs are not) and start a VM from the volume.

This is done in two steps:

* Create a bootable volume from an existing image
* start a new VM using this volume as root disk

To create a bootable volume run:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack volume create --image 2b227d15-8f6a-42b0-b744-ede52ebe59f7 --size 100 pet-1
    +---------------------+--------------------------------------+
    | Field               | Value                                |
    +---------------------+--------------------------------------+
    | attachments         | []                                   |
    | availability_zone   | nova                                 |
    | bootable            | false                                |
    | consistencygroup_id | None                                 |
    | created_at          | 2016-07-26T14:23:38.724790           |
    | description         | None                                 |
    | encrypted           | False                                |
    | id                  | b0520613-fae8-45c0-abbb-13d8a6edc5a2 |
    | multiattach         | False                                |
    | name                | pet-1                                |
    | properties          |                                      |
    | replication_status  | disabled                             |
    | size                | 100                                  |
    | snapshot_id         | None                                 |
    | source_volid        | None                                 |
    | status              | creating                             |
    | type                | default                              |
    | user_id             | anmess                               |
    +---------------------+--------------------------------------+

This might take some time, check the status with `openstack volume
list`

When the volume is created, you can start an instance as before, but
instead of using `--image <image-uuid>` you must use `--volume
<volume-uuid>` (or the volume name, if it's unique), for instance:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server create --nic net-id=c86b320c-9542-4032-a951-c8a068894cc2 --key-name antonio --flavor 1cpu-4ram-hpc --volume pet-1 --security-group default pet-1
    +--------------------------------------+------------------------------------------------------+
    | Field                                | Value                                                |
    +--------------------------------------+------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                               |
    | OS-EXT-AZ:availability_zone          |                                                      |
    | OS-EXT-STS:power_state               | NOSTATE                                              |
    | OS-EXT-STS:task_state                | scheduling                                           |
    | OS-EXT-STS:vm_state                  | building                                             |
    | OS-SRV-USG:launched_at               | None                                                 |
    | OS-SRV-USG:terminated_at             | None                                                 |
    | accessIPv4                           |                                                      |
    | accessIPv6                           |                                                      |
    | addresses                            |                                                      |
    | adminPass                            | fyjDg2hDhFN9                                         |
    | config_drive                         |                                                      |
    | created                              | 2016-07-26T14:31:04Z                                 |
    | flavor                               | 1cpu-4ram-hpc (48fdc4c7-c789-4891-a684-2969ef419ada) |
    | hostId                               |                                                      |
    | id                                   | aad00019-03de-4268-8065-aa4a0b87325a                 |
    | image                                |                                                      |
    | key_name                             | antonio                                              |
    | name                                 | pet-1                                                |
    | os-extended-volumes:volumes_attached | [{u'id': u'b0520613-fae8-45c0-abbb-13d8a6edc5a2'}]   |
    | progress                             | 0                                                    |
    | project_id                           | 92b952a1b50149a687f6b7c8f54eec4b                     |
    | properties                           |                                                      |
    | security_groups                      | [{u'name': u'default'}]                              |
    | status                               | BUILD                                                |
    | updated                              | 2016-07-26T14:31:04Z                                 |
    | user_id                              | anmess                                               |
    +--------------------------------------+------------------------------------------------------+

Note that when you terminate a VM which booted from a volume, this
voume is not deleted. You can always start a new VM from the same
volume, and if you want to delete the volume you have to do it
manually:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server delete pet-1
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack volume list
    +--------------------------------------+-----------------+-----------+------+-------------+
    | ID                                   | Display Name    | Status    | Size | Attached to |
    +--------------------------------------+-----------------+-----------+------+-------------+
    | b0520613-fae8-45c0-abbb-13d8a6edc5a2 | pet-1           | available |  100 |             |
    | 54ad3368-5017-4c94-bc7f-66f25f6b3104 | training_vol_pp | available |   10 |             |
    | f976f1d7-70fd-41ec-8dfe-365da68ca5e7 | tons_of_data    | available |   50 |             |
    +--------------------------------------+-----------------+-----------+------+-------------+
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack volume delete pet-1


### attach volume

Often you will need to create a volume and attach it to the
VM. Remember: volumes are *persistent*, while the root disk of a VM is
not. Also, volumes can be created as big as you want (provided you
have enough quota), while all VMs on ScienceCloud have a root
filesystem of 100GiB.

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server create --nic net-id=c86b320c-9542-4032-a951-c8a068894cc2 --key-name antonio --flavor 1cpu-4ram-hpc --image 2b227d15-8f6a-42b0-b744-ede52ebe59f7 --security-group default anto-test
    +--------------------------------------+--------------------------------------------------------------------------------+
    | Field                                | Value                                                                          |
    +--------------------------------------+--------------------------------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                                                         |
    | OS-EXT-AZ:availability_zone          |                                                                                |
    | OS-EXT-STS:power_state               | NOSTATE                                                                        |
    | OS-EXT-STS:task_state                | scheduling                                                                     |
    | OS-EXT-STS:vm_state                  | building                                                                       |
    | OS-SRV-USG:launched_at               | None                                                                           |
    | OS-SRV-USG:terminated_at             | None                                                                           |
    | accessIPv4                           |                                                                                |
    | accessIPv6                           |                                                                                |
    | addresses                            |                                                                                |
    | adminPass                            | Sj98da6PA2L5                                                                   |
    | config_drive                         |                                                                                |
    | created                              | 2016-07-26T14:34:23Z                                                           |
    | flavor                               | 1cpu-4ram-hpc (48fdc4c7-c789-4891-a684-2969ef419ada)                           |
    | hostId                               |                                                                                |
    | id                                   | 2d87907d-2ffb-4d7b-861c-aabe7b3cf039                                           |
    | image                                | Ubuntu Server 14.04.04 LTS (2016-05-19) (2b227d15-8f6a-42b0-b744-ede52ebe59f7) |
    | key_name                             | antonio                                                                        |
    | name                                 | anto-test                                                                      |
    | os-extended-volumes:volumes_attached | []                                                                             |
    | progress                             | 0                                                                              |
    | project_id                           | 92b952a1b50149a687f6b7c8f54eec4b                                               |
    | properties                           |                                                                                |
    | security_groups                      | [{u'name': u'default'}]                                                        |
    | status                               | BUILD                                                                          |
    | updated                              | 2016-07-26T14:34:23Z                                                           |
    | user_id                              | anmess                                                                         |
    +--------------------------------------+--------------------------------------------------------------------------------+

To create a volume use `openstack volume create`:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack volume create --size 100 data
    +---------------------+--------------------------------------+
    | Field               | Value                                |
    +---------------------+--------------------------------------+
    | attachments         | []                                   |
    | availability_zone   | nova                                 |
    | bootable            | false                                |
    | consistencygroup_id | None                                 |
    | created_at          | 2016-07-26T14:34:43.799217           |
    | description         | None                                 |
    | encrypted           | False                                |
    | id                  | 9915aeb0-bc9c-466c-ad35-46f10bd2b8e5 |
    | multiattach         | False                                |
    | name                | data                                 |
    | properties          |                                      |
    | replication_status  | disabled                             |
    | size                | 100                                  |
    | snapshot_id         | None                                 |
    | source_volid        | None                                 |
    | status              | creating                             |
    | type                | default                              |
    | user_id             | anmess                               |
    +---------------------+--------------------------------------+

To attach the volume use `openstack server add volume <server>
<volume>`

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server add volume anto-test data
    (cloud)(cred:training@sc)anmess@kenny:~$ 

while to detach it:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server remove volume anto-test data

**REMEMBER to always unmount the volume from within the VM first and
 detach it later, otherwise your volume might be inconsistente**

### boot instance using port-id and reuse existing port

Create a port:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack port create --network uzh-only vm-1
    +-----------------------+------------------------------------------------------------------------------------------------------+
    | Field                 | Value                                                                                                |
    +-----------------------+------------------------------------------------------------------------------------------------------+
    | admin_state_up        | UP                                                                                                   |
    | allowed_address_pairs |                                                                                                      |
    | binding_vnic_type     | normal                                                                                               |
    | device_id             |                                                                                                      |
    | device_owner          |                                                                                                      |
    | dns_assignment        | fqdn='host-172-23-51-243.openstacklocal.', hostname='host-172-23-51-243', ip_address='172.23.51.243' |
    | dns_name              |                                                                                                      |
    | fixed_ips             | ip_address='172.23.51.243', subnet_id='f9702c62-9245-471c-a7d0-0b1130d97d58'                         |
    | headers               |                                                                                                      |
    | id                    | 94dfafe4-b2aa-4efb-a08e-9a594cff38af                                                                 |
    | mac_address           | fa:16:3e:75:b8:ec                                                                                    |
    | name                  | vm-1                                                                                                 |
    | network_id            | c86b320c-9542-4032-a951-c8a068894cc2                                                                 |
    | project_id            | 92b952a1b50149a687f6b7c8f54eec4b                                                                     |
    | security_groups       | fae6c332-05a6-4345-99b3-f348af1304e6                                                                 |
    | status                | DOWN                                                                                                 |
    +-----------------------+------------------------------------------------------------------------------------------------------+

An IP (172.23.51.243) and a mac have been automatically assigned to
this port.

Create an instance using the port id instead of the network id. Note
that you can easily get the uuid of the port using `openstack port
show -c id -f value vm-1`

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server create --nic port-id=$(openstack port show -c id -f value vm-1) --key-name antonio --flavor 1cpu-4ram-hpc --image 2b227d15-8f6a-42b0-b744-ede52ebe59f7 --security-group default anto-test
    +--------------------------------------+--------------------------------------------------------------------------------+
    | Field                                | Value                                                                          |
    +--------------------------------------+--------------------------------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                                                         |
    | OS-EXT-AZ:availability_zone          |                                                                                |
    | OS-EXT-STS:power_state               | NOSTATE                                                                        |
    | OS-EXT-STS:task_state                | scheduling                                                                     |
    | OS-EXT-STS:vm_state                  | building                                                                       |
    | OS-SRV-USG:launched_at               | None                                                                           |
    | OS-SRV-USG:terminated_at             | None                                                                           |
    | accessIPv4                           |                                                                                |
    | accessIPv6                           |                                                                                |
    | addresses                            |                                                                                |
    | adminPass                            | EwUfh2DCnY89                                                                   |
    | config_drive                         |                                                                                |
    | created                              | 2016-07-26T14:56:04Z                                                           |
    | flavor                               | 1cpu-4ram-hpc (48fdc4c7-c789-4891-a684-2969ef419ada)                           |
    | hostId                               |                                                                                |
    | id                                   | 1e71c841-24bf-42eb-a0f2-d755d160bcc0                                           |
    | image                                | Ubuntu Server 14.04.04 LTS (2016-05-19) (2b227d15-8f6a-42b0-b744-ede52ebe59f7) |
    | key_name                             | antonio                                                                        |
    | name                                 | anto-test                                                                      |
    | os-extended-volumes:volumes_attached | []                                                                             |
    | progress                             | 0                                                                              |
    | project_id                           | 92b952a1b50149a687f6b7c8f54eec4b                                               |
    | properties                           |                                                                                |
    | security_groups                      | [{u'name': u'default'}]                                                        |
    | status                               | BUILD                                                                          |
    | updated                              | 2016-07-26T14:56:04Z                                                           |
    | user_id                              | anmess                                                                         |
    +--------------------------------------+--------------------------------------------------------------------------------+

The VM will have the MAC and the IP associated with the port:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server list
    +--------------------------------------+-----------+--------+------------------------+
    | ID                                   | Name      | Status | Networks               |
    +--------------------------------------+-----------+--------+------------------------+
    | 1e71c841-24bf-42eb-a0f2-d755d160bcc0 | anto-test | ACTIVE | uzh-only=172.23.51.243 |
    +--------------------------------------+-----------+--------+------------------------+

If you now terminate the instance, the port is not deleted, so that
you can restart an instance using the same port (and more importantly,
IP).

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server delete anto-test
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server list

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack port list
    +--------------------------------------+------+-------------------+------------------------------------------------------------------------------+
    | ID                                   | Name | MAC Address       | Fixed IP Addresses                                                           |
    +--------------------------------------+------+-------------------+------------------------------------------------------------------------------+
    | 2f77f28a-e861-42a9-9d78-2adc6b9409e9 |      | fa:16:3e:bc:4e:b5 | ip_address='10.65.4.2', subnet_id='4892c55f-0f4b-4858-bd10-5c9dcb33135f'     |
    | 8aad5133-65c6-41c7-8eb4-1716312096c5 |      | fa:16:3e:a6:17:00 | ip_address='10.65.4.3', subnet_id='4892c55f-0f4b-4858-bd10-5c9dcb33135f'     |
    | 94dfafe4-b2aa-4efb-a08e-9a594cff38af | vm-1 | fa:16:3e:75:b8:ec | ip_address='172.23.51.243', subnet_id='f9702c62-9245-471c-a7d0-0b1130d97d58' |
    | b0430f22-061a-43fc-a14e-a418aa4894c5 |      | fa:16:3e:40:0a:7a | ip_address='10.65.4.1', subnet_id='4892c55f-0f4b-4858-bd10-5c9dcb33135f'     |
    +--------------------------------------+------+-------------------+------------------------------------------------------------------------------+

To delete a port:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack port delete vm-1

### security groups

You can create a new security group whenever you want.

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack security group list
    +--------------------------------------+---------------------+-------------------------------------------+----------------------------------+
    | ID                                   | Name                | Description                               | Project                          |
    +--------------------------------------+---------------------+-------------------------------------------+----------------------------------+
    | fae6c332-05a6-4345-99b3-f348af1304e6 | default             | Default security group                    | 92b952a1b50149a687f6b7c8f54eec4b |
    +--------------------------------------+---------------------+-------------------------------------------+----------------------------------+
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack security group create web
    +-------------+---------------------------------------------------------------------------------+
    | Field       | Value                                                                           |
    +-------------+---------------------------------------------------------------------------------+
    | description | web                                                                             |
    | headers     |                                                                                 |
    | id          | 61b63e92-a038-481b-b875-4fb29e3a598d                                            |
    | name        | web                                                                             |
    | project_id  | 92b952a1b50149a687f6b7c8f54eec4b                                                |
    | rules       | direction='egress', ethertype='IPv4', id='e7142a8d-d48e-49e3-934a-a667dad5c0e8' |
    |             | direction='egress', ethertype='IPv6', id='522f8407-7524-4cc5-b86c-7885cf6ecc56' |
    +-------------+---------------------------------------------------------------------------------+

To add a new rule to a security group:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack security group rule create --dst-port 80 --protocol tcp web
    +-------------------+--------------------------------------+
    | Field             | Value                                |
    +-------------------+--------------------------------------+
    | direction         | ingress                              |
    | ethertype         | IPv4                                 |
    | headers           |                                      |
    | id                | 344cc13b-a656-4947-a84d-86bd004bd724 |
    | port_range_max    | 80                                   |
    | port_range_min    | 80                                   |
    | project_id        | 92b952a1b50149a687f6b7c8f54eec4b     |
    | protocol          | tcp                                  |
    | remote_group_id   | None                                 |
    | remote_ip_prefix  | 0.0.0.0/0                            |
    | security_group_id | 61b63e92-a038-481b-b875-4fb29e3a598d |
    +-------------------+--------------------------------------+

You can add a security group to a running instance with:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server add security group anto-test web
    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server show anto-test
    +--------------------------------------+--------------------------------------------------------------------------------+
    | Field                                | Value                                                                          |
    +--------------------------------------+--------------------------------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                                                         |
    | OS-EXT-AZ:availability_zone          | nova                                                                           |
    | OS-EXT-STS:power_state               | Running                                                                        |
    | OS-EXT-STS:task_state                | None                                                                           |
    | OS-EXT-STS:vm_state                  | active                                                                         |
    | OS-SRV-USG:launched_at               | 2016-07-26T15:45:24.000000                                                     |
    | OS-SRV-USG:terminated_at             | None                                                                           |
    | accessIPv4                           |                                                                                |
    | accessIPv6                           |                                                                                |
    | addresses                            | uzh-only=172.23.52.24                                                          |
    | config_drive                         |                                                                                |
    | created                              | 2016-07-26T15:45:17Z                                                           |
    | flavor                               | 1cpu-4ram-hpc (48fdc4c7-c789-4891-a684-2969ef419ada)                           |
    | hostId                               | 7beaf4a9a836d81d91ef71956a521c9e10f28499da49e107074c2fdb                       |
    | id                                   | f94d39ef-c9e2-435a-9ddd-ece3220256fe                                           |
    | image                                | Ubuntu Server 14.04.04 LTS (2016-05-19) (2b227d15-8f6a-42b0-b744-ede52ebe59f7) |
    | key_name                             | antonio                                                                        |
    | name                                 | anto-test                                                                      |
    | os-extended-volumes:volumes_attached | []                                                                             |
    | progress                             | 0                                                                              |
    | project_id                           | 92b952a1b50149a687f6b7c8f54eec4b                                               |
    | properties                           |                                                                                |
    | security_groups                      | [{u'name': u'web'}, {u'name': u'default'}]                                     |
    | status                               | ACTIVE                                                                         |
    | updated                              | 2016-07-26T15:45:24Z                                                           |
    | user_id                              | anmess                                                                         |
    +--------------------------------------+--------------------------------------------------------------------------------+


### userdata

The *userdata* is a script that can be passed at creation time and is
executed during the boot of the VM. It is useful to automatically
configure the VM without the need of connecting and installing
software manually.

Create a file called `userdata.sh` with the following content:

    #!/bin/bash

    sudo apt-get update
    sudo apt-get install -y r-base

then start a new VM specifying this as `--user-data`:


    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server create --nic net-id=c86b320c-9542-4032-a951-c8a068894cc2 --key-name antonio --flavor 1cpu-4ram-hpc --image 2b227d15-8f6a-42b0-b744-ede52ebe59f7 --security-group default anto-test --user-data userdata.sh 
    +--------------------------------------+--------------------------------------------------------------------------------+
    | Field                                | Value                                                                          |
    +--------------------------------------+--------------------------------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                                                         |
    | OS-EXT-AZ:availability_zone          |                                                                                |
    | OS-EXT-STS:power_state               | NOSTATE                                                                        |
    | OS-EXT-STS:task_state                | scheduling                                                                     |
    | OS-EXT-STS:vm_state                  | building                                                                       |
    | OS-SRV-USG:launched_at               | None                                                                           |
    | OS-SRV-USG:terminated_at             | None                                                                           |
    | accessIPv4                           |                                                                                |
    | accessIPv6                           |                                                                                |
    | addresses                            |                                                                                |
    | adminPass                            | yNog6KrWpXv2                                                                   |
    | config_drive                         |                                                                                |
    | created                              | 2016-07-26T15:58:58Z                                                           |
    | flavor                               | 1cpu-4ram-hpc (48fdc4c7-c789-4891-a684-2969ef419ada)                           |
    | hostId                               |                                                                                |
    | id                                   | 8573b441-8a70-477b-a7a7-6b1057237685                                           |
    | image                                | Ubuntu Server 14.04.04 LTS (2016-05-19) (2b227d15-8f6a-42b0-b744-ede52ebe59f7) |
    | key_name                             | antonio                                                                        |
    | name                                 | anto-test                                                                      |
    | os-extended-volumes:volumes_attached | []                                                                             |
    | progress                             | 0                                                                              |
    | project_id                           | 92b952a1b50149a687f6b7c8f54eec4b                                               |
    | properties                           |                                                                                |
    | security_groups                      | [{u'name': u'default'}]                                                        |
    | status                               | BUILD                                                                          |
    | updated                              | 2016-07-26T15:58:58Z                                                           |
    | user_id                              | anmess                                                                         |
    +--------------------------------------+--------------------------------------------------------------------------------+

After a reasonable amount of time, you will be able to connect to the
VM and hopefully the userdata will have installed the wanted software
already:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server list
    +--------------------------------------+-----------+--------+-----------------------+
    | ID                                   | Name      | Status | Networks              |
    +--------------------------------------+-----------+--------+-----------------------+
    | 8573b441-8a70-477b-a7a7-6b1057237685 | anto-test | ACTIVE | uzh-only=172.23.52.31 |
    +--------------------------------------+-----------+--------+-----------------------+
    (cloud)(cred:training@sc)anmess@kenny:~$ nossh ubuntu@172.23.52.31
    Warning: Permanently added '172.23.52.31' (ECDSA) to the list of known hosts.
    Welcome to Ubuntu 14.04.4 LTS (GNU/Linux 3.13.0-86-generic x86_64)

     * Documentation:  https://help.ubuntu.com/

      System information as of Tue Jul 26 15:59:09 UTC 2016

      System load: 0.0               Memory usage: 1%   Processes:       55
      Usage of /:  57.6% of 1.32GB   Swap usage:   0%   Users logged in: 0

      Graph this data and manage this system at:
        https://landscape.canonical.com/

      Get cloud support with Ubuntu Advantage Cloud Guest:
        http://www.ubuntu.com/business/services/cloud

    0 packages can be updated.
    0 updates are security updates.



    The programs included with the Ubuntu system are free software;
    the exact distribution terms for each program are described in the
    individual files in /usr/share/doc/*/copyright.

    Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
    applicable law.

    /usr/bin/xauth:  file /home/ubuntu/.Xauthority does not exist
    ubuntu@anto-test:~$ R

    R version 3.0.2 (2013-09-25) -- "Frisbee Sailing"
    Copyright (C) 2013 The R Foundation for Statistical Computing
    Platform: x86_64-pc-linux-gnu (64-bit)

    R is free software and comes with ABSOLUTELY NO WARRANTY.
    You are welcome to redistribute it under certain conditions.
    Type 'license()' or 'licence()' for distribution details.

      Natural language support but running in an English locale

    R is a collaborative project with many contributors.
    Type 'contributors()' for more information and
    'citation()' on how to cite R or R packages in publications.

    Type 'demo()' for some demos, 'help()' for on-line help, or
    'help.start()' for an HTML browser interface to help.
    Type 'q()' to quit R.

    During startup - Warning messages:
    1: Setting LC_TIME failed, using "C" 
    2: Setting LC_MONETARY failed, using "C" 
    3: Setting LC_PAPER failed, using "C" 
    4: Setting LC_MEASUREMENT failed, using "C" 
    >


### instance snapshot

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack server image create --name ubuntu-R anto-test
    +------------------+------------------------------------------------------+
    | Field            | Value                                                |
    +------------------+------------------------------------------------------+
    | base_image_ref   | 2b227d15-8f6a-42b0-b744-ede52ebe59f7                 |
    | checksum         | None                                                 |
    | container_format | bare                                                 |
    | created_at       | 2016-07-26T16:02:40Z                                 |
    | disk_format      | raw                                                  |
    | file             | /v2/images/8ba275f6-5594-41e0-8e99-65136e1e5ed9/file |
    | id               | 8ba275f6-5594-41e0-8e99-65136e1e5ed9                 |
    | image_type       | snapshot                                             |
    | instance_uuid    | 8573b441-8a70-477b-a7a7-6b1057237685                 |
    | min_disk         | 100                                                  |
    | min_ram          | 0                                                    |
    | name             | ubuntu-R                                             |
    | owner            | 92b952a1b50149a687f6b7c8f54eec4b                     |
    | protected        | False                                                |
    | schema           | /v2/schemas/image                                    |
    | size             | 0                                                    |
    | status           | queued                                               |
    | tags             | []                                                   |
    | updated_at       | 2016-07-26T16:02:40Z                                 |
    | user_id          | anmess                                               |
    | virtual_size     | None                                                 |
    | visibility       | private                                              |
    +------------------+------------------------------------------------------+

It will take some time to create the instance:

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack image list
    +--------------------------------------+-------------------------------------------------------+--------+
    | ID                                   | Name                                                  | Status |
    +--------------------------------------+-------------------------------------------------------+--------+
    | 8ba275f6-5594-41e0-8e99-65136e1e5ed9 | ubuntu-R                                              | queued |
    ...
    +--------------------------------------+-------------------------------------------------------+--------+

but after a while...

    (cloud)(cred:training@sc)anmess@kenny:~$ openstack image list
    +--------------------------------------+-------------------------------------------------------+--------+
    | ID                                   | Name                                                  | Status |
    +--------------------------------------+-------------------------------------------------------+--------+
    | 8ba275f6-5594-41e0-8e99-65136e1e5ed9 | ubuntu-R                                              | active |
    ...
    +--------------------------------------+-------------------------------------------------------+--------+


### snapshot of a volume

### lock an instance

### shelve an instance

### attach/detach an interface to a VM


SWIFT (cli)
-----------

- container, accounts, objects
- storage policies
- create container
- upload and download objects
- set metadata
- list using -p and -d

Python API (shade)
------------------

- list instances
- create new instance
- create volume
