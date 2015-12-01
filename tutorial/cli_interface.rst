--------------------------------
OpenStack command line interface
--------------------------------

The CLI is much more powerful than the web interface: many features
are not accessible via web but are via CLI or API.

During this step, we will

Install the CLI
+++++++++++++++

Python virtual environment
--------------------------

Either install `python-virtualenv`, or `download virtualenv from the
web <https://virtualenv.readthedocs.org/en/latest/installation.html>`_

On Ubuntu there is an handy wrapper called `python-virtualenvwrapper`

a virtualenv can be created with::

    antonio@kenny:~$ virtualenv cscs2015
    Running virtualenv with interpreter /usr/bin/python2
    New python executable in cscs2015/bin/python2
    Also creating executable in cscs2015/bin/python
    Installing setuptools, pip...done.

This will create a directory `cscs2015` where everything will be
installed. To uninstall the virtaulenv, just wipe out this directory.

Activate the virtual environment
--------------------------------

Activating the virtual environment requires that you *source* a
script::

    antonio@kenny:~$ . cscs2015/bin/activate
    (cscs2015)antonio@kenny:~$ 

If you see the name of the virtualenv in your prompt, then the
virtualenv is activated.

The activation process will define various environment variables,
including the `PATH` variable. Inside `<venvdir>/bin` you will find a
`python` command, that knows where to find the python packages you
installed in the virtual environment

To deactivate just run `deactivate` (a shell function defined in the
activation script)::

    (cscs2015)antonio@kenny:~$ which pip
    /home/antonio/cscs2015/bin/pip
    (cscs2015)antonio@kenny:~$ deactivate 
    antonio@kenny:~$ which pip
    antonio@kenny:~$ 


Install the cli
---------------

Traditionally every project had his own set of cli tools. During the
year the CLI options have been armonized, and lately a new command
line called `openstack` has been created, that should replace all the
other command lines.

We still need to use the specialized command line tools for some
tasks, as `openstack` command is not yet complete, so we will need to
install the following packages:

* python-openstackclient
* python-novaclient
* python-glanceclient
* python-cinderclient
* python-neutronclient

Please ensure you have ``python-dev`` (on Debian/Ubuntu) or
``python-devel`` (on RedHat/Fedora/CentOS) installed on your laptop
otherwise you may incur into errors during the next steps.

To install a package in a virtual environment just run `pip install
<package-name>` with the virtualenv already loaded::

    (cscs2015)antonio@kenny:~$ pip install python-{openstack,nova,glance,cinder,neutron}client
    [...]
    (cscs2015)antonio@kenny:~$

Configuring the cli
-------------------

In principle the OpenStack commands do not need any configuration: all
parameters needed to interact with the cloud can be passed as command
line options, but it would look like::

    user@ubuntu:~# nova --os-tenant-name demo \
      --os-username demo \
      --os-auth-url http://130.60.24.120:35357/v3 \
      --os-user-domain-id default \
      --os-project-domain-id default \
      --os-password demo \
      list  # the actual command you want to run

However, all the cli we will use also reads these parameters directly
from environment variables, therefore we would suggest you to create a
small shell script that you can `source` to load the needed variables.

A short recap of the variables needed:

+---------------------------+------------------------------------+
| Variable name             | meaning                            |
+===========================+====================================+
| ``OS_USERNAME``           | usernmae                           |
+---------------------------+------------------------------------+
| ``OS_PASSWORD``           | password                           |
+---------------------------+------------------------------------+
| ``OS_AUTH_URL``           | URL to keystone service            |
+---------------------------+------------------------------------+
| ``OS_TENANT_NAME``        | name of the project                |
+---------------------------+------------------------------------+
| ``OS_PROJECT_NAME``       | same as ``OS_TENANT_NAME``         |
+---------------------------+------------------------------------+
| ``OS_USER_DOMAIN_ID``     | user domain (usually `default`)    |
+---------------------------+------------------------------------+
| ``OS_PROJECT_DOMAIN_ID``  | project domain (usually `default`) |
+---------------------------+------------------------------------+
| ``OS_IMAGE_API_VERSION``  | just use `2`                       |
+---------------------------+------------------------------------+
| ``OS_VOLUME_API_VERSION`` | just use `2`                       |
+---------------------------+------------------------------------+

Create a file on your laptop with the following values (update values
for tenant/project name and username)::

    export OS_USERNAME=<USER_ASSIGNED_TO_YOU>
    export OS_PASSWORD=<THE_PASSWORD_YOU_SET>
    export OS_AUTH_URL=http://130.60.24.173:35357/v3
    export OS_TENANT_NAME=<PROJECT_ASSIGNED_TO_YOU>
    export OS_PROJECT_NAME=<PROJECT_ASSIGNED_TO_YOU>
    export OS_USER_DOMAIN_ID=default
    export OS_PROJECT_DOMAIN_ID=default
    export OS_IMAGE_API_VERSION=2
    export OS_VOLUME_API_VERSION=2

and then *source* it with::

    user@ubuntu:~$ . os-credentials.sh

you will be able to just run ``nova list`` to get a list of the
running VMs.

From now on, this guide will assume you loaded the correct environment
variables.

Using the CLI
+++++++++++++

Command line overlap
--------------------

Traditionally, each project had its own set of command lines, with the
same name of the project (thus ``nova`` for Nova, ``glance`` for
Glance etc...). However, there are commands that need to
interact with more than one service, and the command line options were
not well armonized among different projects.

Lately a new super-command has been developed, called
``openstack``. This is intended to replace all the other command line
tools. Since we are still in the transition phase, there are still
things that cannot be done with the ``openstack`` tools. We will try
to use ``openstack`` whenever possible, but some times we will have to
use the older tools.


Getting help
------------

All the CLI have two very useful options:

* --debug
* help

For instance::

    openstack help

will list all the available subcommands. To get information on a
specific subcommand, run::

    openstack help subcommand

Some cli also allow this::

    openstack service list --help

but most of the legacy ones don't.

Also, to understand what's happening and to debug some issues, it's
useful to run the command with ``--debug``. This will print all the
http requests that the tools are doing::

    openstack --debug server list


Keypairs
--------

You can list the keypairs with::

    user@ubuntu:~$ openstack keypair list
    +---------+-------------------------------------------------+
    | Name    | Fingerprint                                     |
    +---------+-------------------------------------------------+
    | antonio | 61:ba:f9:16:8e:33:05:e6:8a:bf:cb:95:1f:40:9a:a0 |
    +---------+-------------------------------------------------+

and of course delete them::

    openstack keypaiar delete <keypairname>

or import a new one::

    openstack keypair-create --public-key <path-to-ssh-pub-key> antonio

Networking
----------

Networking is complex and the ``neutron`` command line interface
isn't helping.

As a recap, you have different concepts in neutron:

* net: an L2 network, defines:

  - the implementation (vlan/gre/vxlan/flat)
  - if it's external or not
  - if it's shared or not
  - if security is enabled globally for the network
  
* subnet: an L3 network. Defines:

  - an IPs CIDR
  - if dhcp is running
  - gateway for the network
  - optionally, dns servers
  - extra routes
  - a pool of "usable" IPs within the CIDR

* port: a virtual port, that could be attached to a router, a VM or
  any other virtual device. Defines:

  - a mac address
  - an IP
  - security groups associated with the port
  - the administrative state

* router: an L3 agent that runs on a network node. Contains:

  - a list of interfaces (ports) attached to neutron networks
  - a default gateway

* floating ip: an ip from a pool of valid IPs of an external network
  that can be associated to a neutron port. Internally, an L3 agent
  will provide 1:1 NAT to access the internal IP of the port using the
  floating IP.

* security groups: set of firewall rules associated with a port. Some
  firewall rules to prevent spoofing are automatically added and are
  not shown in the list of rules of a security group

For each one of them you have neutron commands to list, create,
delete, manage these artifacts.

Delete previous environment
---------------------------

Deleting could be tricky, because you have to do it in the proper
order.

I have the following networks::

    user@ubuntu:~$ neutron net-list
    +--------------------------------------+------------------+-----------------------------------------------------+
    | id                                   | name             | subnets                                             |
    +--------------------------------------+------------------+-----------------------------------------------------+
    | 4cb131d5-5ece-4122-9014-ac069cd8d4a3 | uzh-public       | 229925c8-8705-479f-bddb-0c52a5c618ad                |
    | 9a4ce8c1-950c-4432-86ef-a8ba4a9d0e28 | openstack-public | 42a0c86a-4ee4-4599-91a6-4adc720df0f3 10.0.0.0/24    |
    | dad2ca78-380e-48aa-8454-1218feb47947 | openstack-priv   | affa73b3-17ac-4304-a5af-15cdee285b25 192.168.1.0/24 |
    +--------------------------------------+------------------+-----------------------------------------------------+

and router::

    user@ubuntu:~$ neutron router-list
    +--------------------------------------+--------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | id                                   | name                           | external_gateway_info                                                                                                                                                                     |
    +--------------------------------------+--------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | 56dc2140-5c86-412a-a751-00a1cfb9f2a1 | openstack-public-to-uzh-public | {"network_id": "4cb131d5-5ece-4122-9014-ac069cd8d4a3", "enable_snat": true, "external_fixed_ips": [{"subnet_id": "229925c8-8705-479f-bddb-0c52a5c618ad", "ip_address": "130.60.24.117"}]} |
    +--------------------------------------+--------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

the router has the following interfaces::

    user@ubuntu:~$ neutron router-port-list 56dc2140-5c86-412a-a751-00a1cfb9f2a1
    +--------------------------------------+------+-------------------+---------------------------------------------------------------------------------+
    | id                                   | name | mac_address       | fixed_ips                                                                       |
    +--------------------------------------+------+-------------------+---------------------------------------------------------------------------------+
    | f954ace7-5c0a-449e-b871-3cf71d104120 |      | fa:16:3e:eb:96:42 | {"subnet_id": "42a0c86a-4ee4-4599-91a6-4adc720df0f3", "ip_address": "10.0.0.1"} |
    +--------------------------------------+------+-------------------+---------------------------------------------------------------------------------+

and the following VMs::

    user@ubuntu:~$ nova list
    +--------------------------------------+--------------+--------+------------+-------------+----------------------------------------------------------------------+
    | ID                                   | Name         | Status | Task State | Power State | Networks                                                             |
    +--------------------------------------+--------------+--------+------------+-------------+----------------------------------------------------------------------+
    | b544fbe8-b7f8-447b-9ae7-4603377fcd3a | auth-node    | ACTIVE | -          | Running     | openstack-priv=192.168.1.6                                           |
    | 8c03b65a-1c2f-46f6-a96b-db37ecd17955 | bastion      | ACTIVE | -          | Running     | openstack-priv=192.168.1.4; openstack-public=10.0.0.4, 130.60.24.120 |
    | 5bfaa6fb-4077-4340-9dc0-8fe7fba03378 | compute-node | ACTIVE | -          | Running     | openstack-priv=192.168.1.9                                           |
    | 60c24795-959e-4f3c-8773-3bff480de637 | db-node      | ACTIVE | -          | Running     | openstack-priv=192.168.1.5                                           |
    | c86e1c2f-b90a-4bc4-9151-e4eb8f5c9ab1 | hypervisor-1 | ACTIVE | -          | Running     | openstack-priv=192.168.1.10                                          |
    | 6de9318f-2b79-45fa-b184-92b342faba89 | hypervisor-2 | ACTIVE | -          | Running     | openstack-priv=192.168.1.11                                          |
    | 020e3141-2673-4cda-ad73-e0fa309c62eb | image-node   | ACTIVE | -          | Running     | openstack-priv=192.168.1.7                                           |
    | 40599fee-ca3b-4247-8fc7-bd765bd132b1 | network-node | ACTIVE | -          | Running     | openstack-priv=192.168.1.12; openstack-public=10.0.0.5               |
    | fe79b2c7-e9df-44f2-8c6a-d431d3dc1305 | volume-node  | ACTIVE | -          | Running     | openstack-priv=192.168.1.8                                           |
    +--------------------------------------+--------------+--------+------------+-------------+----------------------------------------------------------------------+

To delete everything I have to:

* ensure no VMs are running
* remove all interfaces from the router to the private network
* unset the gateway on the router
* delete networks and router

Delete the VMs::

    user@ubuntu:~$ nova delete auth-node bastion compute-node db-node hypervisor-1 hypervisor-2 image-node network-node volume-node
    Request to delete server auth-node has been accepted.
    Request to delete server bastion has been accepted.
    Request to delete server compute-node has been accepted.
    Request to delete server db-node has been accepted.
    Request to delete server hypervisor-1 has been accepted.
    Request to delete server hypervisor-2 has been accepted.
    Request to delete server image-node has been accepted.
    Request to delete server network-node has been accepted.
    Request to delete server volume-node has been accepted.


remove router interfaces::

    user@ubuntu:~$ neutron router-interface-delete 56dc2140-5c86-412a-a751-00a1cfb9f2a1 42a0c86a-4ee4-4599-91a6-4adc720df0f3
    Removed interface from router 56dc2140-5c86-412a-a751-00a1cfb9f2a1.

clear the gateway::

    user@ubuntu:~$ neutron router-gateway-clear 56dc2140-5c86-412a-a751-00a1cfb9f2a1
    Removed gateway from router 56dc2140-5c86-412a-a751-00a1cfb9f2a1

delete the router::

    user@ubuntu:~$ neutron router-delete 56dc2140-5c86-412a-a751-00a1cfb9f2a1
    Deleted router: 56dc2140-5c86-412a-a751-00a1cfb9f2a1

delete the networks::

    user@ubuntu:~$ neutron net-delete openstack-public
    Deleted network: openstack-public
    user@ubuntu:~$ neutron net-delete openstack-priv
    Deleted network: openstack-priv

Create network and router
-------------------------

A creation of a network is a two step process:

* create the network
* create a subnet inside the network

Create a network::

    user@ubuntu:~$ neutron net-create os-public
    Created a new network:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | id                    | c7789baa-45d2-41a5-9ab2-0f938b220014 |
    | mtu                   | 0                                    |
    | name                  | os-public                            |
    | port_security_enabled | True                                 |
    | router:external       | False                                |
    | shared                | False                                |
    | status                | ACTIVE                               |
    | subnets               |                                      |
    | tenant_id             | 648477bbdd0747bfa07497194f20aac3     |
    +-----------------------+--------------------------------------+

As user you have limited choices when creating a network, but as an
admin, you can also create an **external** network (a network that
that is linked to a physical interface), and you can specify different
implementation methods (depending on the configuration). For instance,
you can create a network that is mapped to a specific vlan of your
physical infrastructure, so that your VMs will be able to talk
directly to physical machines in that vlan.

Create a subnet::

    user@ubuntu:~$ neutron subnet-create os-public 10.0.0.0/24 --name os-public-subnet
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
    | id                | 92c23149-c6cf-4038-b05a-57f21455ec40       |
    | ip_version        | 4                                          |
    | ipv6_address_mode |                                            |
    | ipv6_ra_mode      |                                            |
    | name              |                                            |
    | network_id        | c7789baa-45d2-41a5-9ab2-0f938b220014       |
    | subnetpool_id     |                                            |
    | tenant_id         | 648477bbdd0747bfa07497194f20aac3           |
    +-------------------+--------------------------------------------+

By default the network will assume there is a gateway and a dhcp. You
can create an *isolated* network with ``--no-gateway``.

You can also disable the dhcp server, but in that case you will need
to configure the networking manually within the VM.

Create a router::

    user@ubuntu:~$ neutron router-create pub-to-ext
    Created a new router:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | external_gateway_info |                                      |
    | id                    | a39dd1f6-0cf8-496d-8f1b-8fe834af7fac |
    | name                  | pub-to-ext                           |
    | routes                |                                      |
    | status                | ACTIVE                               |
    | tenant_id             | 648477bbdd0747bfa07497194f20aac3     |
    +-----------------------+--------------------------------------+

set the default gateway::

    user@ubuntu:~$ neutron router-gateway-set pub-to-ext uzh-public
    Set gateway for router pub-to-ext

if you don't know which external network are available, run::

    user@ubuntu:~$ neutron net-external-list
    +--------------------------------------+------------+---------------------------------------+
    | id                                   | name       | subnets                               |
    +--------------------------------------+------------+---------------------------------------+
    | 4cb131d5-5ece-4122-9014-ac069cd8d4a3 | uzh-public | 229925c8-8705-479f-bddb-0c52a5c618ad  |
    +--------------------------------------+------------+---------------------------------------+

finally, add an interface from ``os-public` to the router::

    user@ubuntu:~$ neutron router-interface-add pub-to-ext os-public-subnet
    Added interface ed45c9a1-af56-4d4b-ba5e-69280684b4c0 to router pub-to-ext.

Starting a VM
-------------

To start a VM you *need* to specify:

* a flavor
* an image
* possibly, a keypair
* possibly, one or more security group (`default` is used otherwise)
* possibly, at least one network interface
* a name

You can either use ``nova`` or ``openstack`` to get these
informations.

List the available flavors::

    user@ubuntu:~$ openstack flavor list
    +----+-----------+-------+------+-----------+-------+-----------+
    | ID | Name      |   RAM | Disk | Ephemeral | VCPUs | Is Public |
    +----+-----------+-------+------+-----------+-------+-----------+
    | 1  | m1.tiny   |   512 |    1 |         0 |     1 | True      |
    | 2  | m1.small  |  2048 |   20 |         0 |     1 | True      |
    | 3  | m1.medium |  4096 |   40 |         0 |     2 | True      |
    | 4  | m1.large  |  8192 |   80 |         0 |     4 | True      |
    | 5  | m1.xlarge | 16384 |  160 |         0 |     8 | True      |
    +----+-----------+-------+------+-----------+-------+-----------+

More information on a flavor can be shown with::

    user@ubuntu:~$ openstack flavor show m1.tiny
    +----------------------------+---------+
    | Field                      | Value   |
    +----------------------------+---------+
    | OS-FLV-DISABLED:disabled   | False   |
    | OS-FLV-EXT-DATA:ephemeral  | 0       |
    | disk                       | 1       |
    | id                         | 1       |
    | name                       | m1.tiny |
    | os-flavor-access:is_public | True    |
    | properties                 |         |
    | ram                        | 512     |
    | rxtx_factor                | 1.0     |
    | swap                       |         |
    | vcpus                      | 1       |
    +----------------------------+---------+

same for images::

    user@ubuntu:~$ openstack image list
    +--------------------------------------+---------------------+
    | ID                                   | Name                |
    +--------------------------------------+---------------------+
    | 588e1d38-c9ba-4481-a484-67bbc83935b3 | ubuntu-trusty       |
    | 704dbb04-0d04-404a-87d8-978dae8120e3 | cirros-0.3.4-x86_64 |
    +--------------------------------------+---------------------+

::

    user@ubuntu:~$ openstack image show ubuntu-trusty
    +------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
    | Field            | Value                                                                                                                                      |
    +------------------+--------------------------------------------------------------------------------------------------------------------------------------------+
    | checksum         | f220606a2601a610e51ec2a58cc6a967                                                                                                           |
    | container_format | bare                                                                                                                                       |
    | created_at       | 2015-11-14T13:33:34Z                                                                                                                       |
    | disk_format      | raw                                                                                                                                        |
    | file             | /v2/images/588e1d38-c9ba-4481-a484-67bbc83935b3/file                                                                                       |
    | id               | 588e1d38-c9ba-4481-a484-67bbc83935b3                                                                                                       |
    | min_disk         | 4                                                                                                                                          |
    | min_ram          | 0                                                                                                                                          |
    | name             | ubuntu-trusty                                                                                                                              |
    | owner            | 6a8c8c3ed987477b82f475742d695fef                                                                                                           |
    | properties       | description='', direct_url='rbd://7705608d-cbef-477a-865d-f5ae4c03370a/test/588e1d38-c9ba-4481-a484-67bbc83935b3/snap', os_distro='ubuntu' |
    | protected        | False                                                                                                                                      |
    | schema           | /v2/schemas/image                                                                                                                          |
    | size             | 2361393152                                                                                                                                 |
    | status           | active                                                                                                                                     |
    | tags             |                                                                                                                                            |
    | updated_at       | 2015-11-16T14:00:30Z                                                                                                                       |
    | virtual_size     | None                                                                                                                                       |
    | visibility       | public                                                                                                                                     |
    +------------------+--------------------------------------------------------------------------------------------------------------------------------------------+

We already know the available networks we have, so let's start our
first VM from the CLI::

    user@ubuntu:~$ openstack server create \
      --image ubuntu-trusty \
      --key-name antonio \
      --flavor m1.small \
      --nic net-id=c7789baa-45d2-41a5-9ab2-0f938b220014 \
      test-1
    +--------------------------------------+------------------------------------------------------+
    | Field                                | Value                                                |
    +--------------------------------------+------------------------------------------------------+
    | OS-DCF:diskConfig                    | MANUAL                                               |
    | OS-EXT-AZ:availability_zone          | nova                                                 |
    | OS-EXT-STS:power_state               | 0                                                    |
    | OS-EXT-STS:task_state                | None                                                 |
    | OS-EXT-STS:vm_state                  | building                                             |
    | OS-SRV-USG:launched_at               | None                                                 |
    | OS-SRV-USG:terminated_at             | None                                                 |
    | accessIPv4                           |                                                      |
    | accessIPv6                           |                                                      |
    | addresses                            |                                                      |
    | adminPass                            | jbeTTTRF3pn4                                         |
    | config_drive                         |                                                      |
    | created                              | 2015-11-29T11:44:49Z                                 |
    | flavor                               | m1.small (2)                                         |
    | hostId                               |                                                      |
    | id                                   | 9707e7d9-7d89-4205-b70b-944b1b23bcec                 |
    | image                                | ubuntu-trusty (588e1d38-c9ba-4481-a484-67bbc83935b3) |
    | key_name                             | antonio                                              |
    | name                                 | test-1                                               |
    | os-extended-volumes:volumes_attached | []                                                   |
    | progress                             | 0                                                    |
    | project_id                           | 648477bbdd0747bfa07497194f20aac3                     |
    | properties                           |                                                      |
    | security_groups                      | [{u'name': u'default'}]                              |
    | status                               | BUILD                                                |
    | updated                              | 2015-11-29T11:44:49Z                                 |
    | user_id                              | 71aad312e9bf420b8cfe83715b60e691                     |
    +--------------------------------------+------------------------------------------------------+

As long as the name is unique in the tenant, you can refer to VMs
using their name, otherwise you will have to use the
not-so-user-friendly uuid.

When the status of the VM is ``ACTIVE`` it meens that it has been
started on the hypervisor. It doesn't mean that it's actually up and running::
    
    user@ubuntu:~$ openstack server list
    +--------------------------------------+--------+--------+--------------------+
    | ID                                   | Name   | Status | Networks           |
    +--------------------------------------+--------+--------+--------------------+
    | 9707e7d9-7d89-4205-b70b-944b1b23bcec | test-1 | ACTIVE | os-public=10.0.0.3 |
    +--------------------------------------+--------+--------+--------------------+

You can get the serial console of a VM using::

    user@ubuntu:~$ openstack console log show test-1
    ...
    Cloud-init v. 0.7.5 running 'modules:final' at Sun, 29 Nov 2015 11:45:16 +0000. Up 20.62 seconds.
    ci-info: ++++++Authorized keys from /home/ubuntu/.ssh/authorized_keys for user ubuntu+++++++
    ci-info: +---------+-------------------------------------------------+---------+-----------+
    ci-info: | Keytype |                Fingerprint (md5)                | Options |  Comment  |
    ci-info: +---------+-------------------------------------------------+---------+-----------+
    ci-info: | ssh-dss | 61:ba:f9:16:8e:33:05:e6:8a:bf:cb:95:1f:40:9a:a0 |    -    | anto@nano |
    ci-info: +---------+-------------------------------------------------+---------+-----------+
    ec2: 
    ec2: #############################################################
    ec2: -----BEGIN SSH HOST KEY FINGERPRINTS-----
    ec2: 1024 20:d0:54:ce:8f:7a:e1:12:8c:d1:db:92:b8:24:b3:08  root@test-1 (DSA)
    ec2: 256 73:ea:f4:67:0f:65:b6:08:ef:e1:f1:4c:88:c7:0e:b5  root@test-1 (ECDSA)
    ec2: 256 35:b1:d6:45:2b:37:88:d6:79:93:7a:f0:45:f5:0e:a0  root@test-1 (ED25519)
    ec2: 2048 76:30:e2:9f:7e:41:66:b4:4e:0e:f0:60:3d:63:00:c2  root@test-1 (RSA)
    ec2: -----END SSH HOST KEY FINGERPRINTS-----
    ec2: #############################################################
    -----BEGIN SSH HOST KEY KEYS-----
    ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBB24uUWUV5GfyIvsQkcxijLEtMEWe1ZIRyWCRrbDVC1mG2FB8isBrCQAcQ6Mmo93z9DgLo1L21OLM/hqvztmhUA= root@test-1
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4XYBb6fywcwFH4xw+Z3ohLEC0LXION0B8pDYQR185n root@test-1
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8N63jhVutgwhaHXmXv2F3Aa/hOhEHn32uQFILrxIbrJHnGGgrcelFy3HxjBE4KHq/969j3ZhUUwg/ZOOr0tnguw9PqxhFniQyFG6darEvyii3GMBdQ3zECnVAW5uOJyjX7McmDvGAPVwGxInIyX1WALbhlA5Q5tJeMuNp+ljECwjrgz8x+XIXbPBHSw31O0Eu+zPndAV/knPACa+vSjasRJ/33x5j/9dmZETmzFJXsqdDsiT5IDRju4hJUfUcit8yGsIioJ9hFtOaYL5/mrG6YmhdY2T7EM8IcEupKBG+mbDnPGMLKF5Z+mUymJdQx/aizoTJMI+n8fLE7mDzTOvx root@test-1
    -----END SSH HOST KEY KEYS-----
    Cloud-init v. 0.7.5 finished at Sun, 29 Nov 2015 11:45:16 +0000. Datasource DataSourceOpenStack [net,ver=2].  Up 20.70 seconds
    
    Ubuntu 14.04.3 LTS test-1 ttyS0
    
    test-1 login: 

This is the standard output of a VM correctly started: it got the
correct keypair and it should be ready to work.

We cannot login to it yet, as the IP is private. Before we are able
to, we need to associate a floating IP and ensure security groups
allow us to ssh on it.

Floating IPs
------------

Floating IPs are public IPs (i.e. IPs in an external network, created
by an admin) that can be allocated to a tenant and then associated to
a VM.

It's *usually* the only way to connect to a VM, although there are
ways to give to a VM an interface directly attached to an external
network, but it's a less common setup.

When you *create* a floating IP you are actually allocating it for the
tenant: nobody else can use it, unless you *delete* it or the
administrator does it.

You can list the floating IPs allocated for your project with::

    user@ubuntu:~$ openstack ip floating list

and you can allocate one with::

    user@ubuntu:~$ openstack ip floating create uzh-public
    +-------------+--------------------------------------+
    | Field       | Value                                |
    +-------------+--------------------------------------+
    | fixed_ip    | None                                 |
    | id          | d350ee9d-59b4-4102-8c9c-b3900b326434 |
    | instance_id | None                                 |
    | ip          | 130.60.24.128                        |
    | pool        | uzh-public                           |
    +-------------+--------------------------------------+

::

    user@ubuntu:~$ openstack ip floating list
    +--------------------------------------+------------+---------------+----------+-------------+
    | ID                                   | Pool       | IP            | Fixed IP | Instance ID |
    +--------------------------------------+------------+---------------+----------+-------------+
    | d350ee9d-59b4-4102-8c9c-b3900b326434 | uzh-public | 130.60.24.128 | None     | None        |
    +--------------------------------------+------------+---------------+----------+-------------+

then, you can associate it to your VMs::

    user@ubuntu:~$ openstack ip floating add 130.60.24.128 test-1

You will see the floating IP among the IPs associated to the VM::

    user@ubuntu:~$ openstack server list
    +--------------------------------------+--------+--------+-----------------------------------+
    | ID                                   | Name   | Status | Networks                          |
    +--------------------------------------+--------+--------+-----------------------------------+
    | 9707e7d9-7d89-4205-b70b-944b1b23bcec | test-1 | ACTIVE | os-public=10.0.0.3, 130.60.24.128 |
    +--------------------------------------+--------+--------+-----------------------------------+

or again running ``openstack ip floating list``::

    user@ubuntu:~$ openstack ip floating list
    +--------------------------------------+------------+---------------+----------+--------------------------------------+
    | ID                                   | Pool       | IP            | Fixed IP | Instance ID                          |
    +--------------------------------------+------------+---------------+----------+--------------------------------------+
    | d350ee9d-59b4-4102-8c9c-b3900b326434 | uzh-public | 130.60.24.128 | 10.0.0.3 | 9707e7d9-7d89-4205-b70b-944b1b23bcec |
    +--------------------------------------+------------+---------------+----------+--------------------------------------+

You can disassociate a floating IP  from a VM with ``openstack ip
floating remove`` and release the floating IP with ``openstack ip
floating delete``

Now we should be able to directly connect to the VM from the lab
network::

    user@ubuntu:~$ ssh ubuntu@130.60.24.128
    ssh: connect to host 130.60.24.128 port 22: Connection timed out

or not?

Security groups
---------------

Security groups are firewall rules associated with a port. They can be
listed with::

    user@ubuntu:~$ openstack security group list
    +--------------------------------------+-----------+------------------------+
    | ID                                   | Name      | Description            |
    +--------------------------------------+-----------+------------------------+
    | 640d2c0a-3e89-404e-9875-1e7bbac1c9f1 | default   | Default security group |
    | 1eedbc48-f197-4886-8226-554c7ade4f78 | openstack | openstack              |
    | 57e7ae6a-d833-4423-9705-85ba9f22f5f9 | vncproxy  | vncproxy               |
    +--------------------------------------+-----------+------------------------+

You can list the rules of a security group with::

    user@ubuntu:~$ openstack security group rule list default
    +--------------------------------------+-------------+-----------+------------+
    | ID                                   | IP Protocol | IP Range  | Port Range |
    +--------------------------------------+-------------+-----------+------------+
    | 3bab0263-b177-4935-923f-edcdd4fb9fd2 |             |           |            |
    | 85c702f4-107f-4aeb-9098-dd0f17751399 |             |           |            |
    +--------------------------------------+-------------+-----------+------------+

clearly, something seems missing...

Traditionally, security groups were only blocking incoming packets,
but neutron is much more sofisticated than this. The ``openstack`` and
``nova`` cli will show you the incoming rules only, and leave blank
all the others.

`neutron` cli will give you much more (too much?) information::

    user@ubuntu:~$ neutron security-group-list
    +--------------------------------------+-----------+----------------------------------------------------------------------+
    | id                                   | name      | security_group_rules                                                 |
    +--------------------------------------+-----------+----------------------------------------------------------------------+
    | 1eedbc48-f197-4886-8226-554c7ade4f78 | openstack | egress, IPv4                                                         |
    |                                      |           | egress, IPv6                                                         |
    |                                      |           | ingress, IPv4, 35357/tcp, remote_ip_prefix: 0.0.0.0/0                |
    |                                      |           | ingress, IPv4, 5000/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 6080/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 80/tcp, remote_ip_prefix: 0.0.0.0/0                   |
    |                                      |           | ingress, IPv4, 8773/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 8774/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 8775/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 8776/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 9191/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 9292/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    |                                      |           | ingress, IPv4, 9696/tcp, remote_ip_prefix: 0.0.0.0/0                 |
    | 57e7ae6a-d833-4423-9705-85ba9f22f5f9 | vncproxy  | egress, IPv4                                                         |
    |                                      |           | egress, IPv6                                                         |
    |                                      |           | ingress, IPv4, 5900-6000/tcp, remote_ip_prefix: 0.0.0.0/0            |
    | 640d2c0a-3e89-404e-9875-1e7bbac1c9f1 | default   | egress, IPv4                                                         |
    |                                      |           | egress, IPv6                                                         |
    |                                      |           | ingress, IPv4, remote_group_id: 640d2c0a-3e89-404e-9875-1e7bbac1c9f1 |
    |                                      |           | ingress, IPv6, remote_group_id: 640d2c0a-3e89-404e-9875-1e7bbac1c9f1 |
    +--------------------------------------+-----------+----------------------------------------------------------------------+

Let's update the `default` security group, already associated to our
`test-1` vm. We want to allow ssh connection. One nice thing about
security groups is that you can change them live, and the changes are
automatically applied to all the ports that uses that security group.

Also, you can dynamically add or remove security groups to ports (or
to VMs, which means add/remove to all the ports of that server).

Let's add a simple rule to enable ssh connection to the `default`
security group::

    user@ubuntu:~$ openstack security group rule create --dst-port 22 --proto tcp default
    +-----------------+--------------------------------------+
    | Field           | Value                                |
    +-----------------+--------------------------------------+
    | group           | {}                                   |
    | id              | 187348ce-e8b9-4499-b4d3-413191f860bf |
    | ip_protocol     | tcp                                  |
    | ip_range        | 0.0.0.0/0                            |
    | parent_group_id | 640d2c0a-3e89-404e-9875-1e7bbac1c9f1 |
    | port_range      | 22:22                                |
    +-----------------+--------------------------------------+

and try again::

    user@ubuntu:~$ ssh ubuntu@130.60.24.128
    Warning: Permanently added '130.60.24.128' (ECDSA) to the list of known hosts.
    Welcome to Ubuntu 14.04.3 LTS (GNU/Linux 3.13.0-68-generic x86_64)

     * Documentation:  https://help.ubuntu.com/

      System information as of Sun Nov 29 11:59:55 UTC 2015

      System load:  0.0               Processes:           69
      Usage of /:   3.9% of 19.65GB   Users logged in:     0
      Memory usage: 2%                IP address for eth0: 10.0.0.3
      Swap usage:   0%

      Graph this data and manage this system at:
        https://landscape.canonical.com/

      Get cloud support with Ubuntu Advantage Cloud Guest:
        http://www.ubuntu.com/business/services/cloud

    0 packages can be updated.
    0 updates are security updates.


    Last login: Sun Nov 29 11:59:58 2015 from 2.236.130.253
    ubuntu@test-1:~$ 

(note: you can also use ``openstack server ssh test-1 -l ubuntu``)

In some cases you need to add a security group to a VM after this has
been started::

    user@ubuntu:~$ openstack server add security group test-1 openstack

In other cases, however, you want to remove any security protection
on a specific port. This requires that the neutron services are
properly configured, and must be done using ``neutron`` command line.

First, you need to know which port is associated with your VM::

    user@ubuntu:~$ nova interface-list test-1
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+
    | Port State | Port ID                              | Net ID                               | IP addresses | MAC Addr          |
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+
    | ACTIVE     | fe5a01d8-7274-4d9e-b14e-f129feb95afe | c7789baa-45d2-41a5-9ab2-0f938b220014 | 10.0.0.3     | fa:16:3e:7f:83:b5 |
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+

You can show details about the port with::

    user@ubuntu:~$ neutron port-show fe5a01d8-7274-4d9e-b14e-f129feb95afe
    +-----------------------+---------------------------------------------------------------------------------+
    | Field                 | Value                                                                           |
    +-----------------------+---------------------------------------------------------------------------------+
    | admin_state_up        | True                                                                            |
    | allowed_address_pairs |                                                                                 |
    | binding:vnic_type     | normal                                                                          |
    | device_id             | 9707e7d9-7d89-4205-b70b-944b1b23bcec                                            |
    | device_owner          | compute:None                                                                    |
    | extra_dhcp_opts       |                                                                                 |
    | fixed_ips             | {"subnet_id": "92c23149-c6cf-4038-b05a-57f21455ec40", "ip_address": "10.0.0.3"} |
    | id                    | fe5a01d8-7274-4d9e-b14e-f129feb95afe                                            |
    | mac_address           | fa:16:3e:7f:83:b5                                                               |
    | name                  |                                                                                 |
    | network_id            | c7789baa-45d2-41a5-9ab2-0f938b220014                                            |
    | port_security_enabled | True                                                                            |
    | security_groups       | 1eedbc48-f197-4886-8226-554c7ade4f78                                            |
    |                       | 640d2c0a-3e89-404e-9875-1e7bbac1c9f1                                            |
    | status                | ACTIVE                                                                          |
    | tenant_id             | 648477bbdd0747bfa07497194f20aac3                                                |
    +-----------------------+---------------------------------------------------------------------------------+

You can then remove all the security groups and disable the
``port-security-enabled`` feature with::

    user@ubuntu:~$ neutron port-update --no-security-groups --port-security-enabled=False fe5a01d8-7274-4d9e-b14e-f129feb95afe
    Updated port: fe5a01d8-7274-4d9e-b14e-f129feb95afe
    user@ubuntu:~$ neutron port-show fe5a01d8-7274-4d9e-b14e-f129feb95afe
    +-----------------------+---------------------------------------------------------------------------------+
    | Field                 | Value                                                                           |
    +-----------------------+---------------------------------------------------------------------------------+
    | admin_state_up        | True                                                                            |
    | allowed_address_pairs |                                                                                 |
    | binding:vnic_type     | normal                                                                          |
    | device_id             | 9707e7d9-7d89-4205-b70b-944b1b23bcec                                            |
    | device_owner          | compute:None                                                                    |
    | extra_dhcp_opts       |                                                                                 |
    | fixed_ips             | {"subnet_id": "92c23149-c6cf-4038-b05a-57f21455ec40", "ip_address": "10.0.0.3"} |
    | id                    | fe5a01d8-7274-4d9e-b14e-f129feb95afe                                            |
    | mac_address           | fa:16:3e:7f:83:b5                                                               |
    | name                  |                                                                                 |
    | network_id            | c7789baa-45d2-41a5-9ab2-0f938b220014                                            |
    | port_security_enabled | False                                                                           |
    | security_groups       |                                                                                 |
    | status                | ACTIVE                                                                          |
    | tenant_id             | 648477bbdd0747bfa07497194f20aac3                                                |
    +-----------------------+---------------------------------------------------------------------------------+

Adding a network interface
--------------------------

You can dynamically add or remove a network interface to/from a
running instance.

Let's create an isolated network::

    user@ubuntu:~$  neutron subnet-create priv-net --name priv-subnet --no-gateway
    Bad subnets request: A cidr must be specified in the absence of a subnet pool
    user@ubuntu:~$  neutron subnet-create  --name priv-subnet --no-gateway priv-net 10.99.0.0/24
    Created a new subnet:
    +-------------------+----------------------------------------------+
    | Field             | Value                                        |
    +-------------------+----------------------------------------------+
    | allocation_pools  | {"start": "10.99.0.1", "end": "10.99.0.254"} |
    | cidr              | 10.99.0.0/24                                 |
    | dns_nameservers   |                                              |
    | enable_dhcp       | True                                         |
    | gateway_ip        |                                              |
    | host_routes       |                                              |
    | id                | e82d94d4-e3fb-40af-8fc8-dd80107b597d         |
    | ip_version        | 4                                            |
    | ipv6_address_mode |                                              |
    | ipv6_ra_mode      |                                              |
    | name              | priv-subnet                                  |
    | network_id        | 4834a6b3-af27-48d4-8326-fe12138d23c9         |
    | subnetpool_id     |                                              |
    | tenant_id         | 648477bbdd0747bfa07497194f20aac3             |
    +-------------------+----------------------------------------------+

and then, let's add an interface to the VM::

    user@ubuntu:~$ nova interface-attach --net-id 4834a6b3-af27-48d4-8326-fe12138d23c9 test-1
    user@ubuntu:~$ nova interface-list test-1
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+
    | Port State | Port ID                              | Net ID                               | IP addresses | MAC Addr          |
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+
    | ACTIVE     | 892e33d9-3d26-426b-9238-a4b0f158cfbc | 4834a6b3-af27-48d4-8326-fe12138d23c9 | 10.99.0.2    | fa:16:3e:af:92:31 |
    | ACTIVE     | fe5a01d8-7274-4d9e-b14e-f129feb95afe | c7789baa-45d2-41a5-9ab2-0f938b220014 | 10.0.0.3     | fa:16:3e:7f:83:b5 |
    +------------+--------------------------------------+--------------------------------------+--------------+-------------------+


.. _lab-exercise-2:

Lab Exercise 2
++++++++++++++

In this lab exercise you are requested to:

**Install a SLURM cluster using the CLI only**

Requirements:

* you can only use the command line
* the cluster will be composed of the following nodes:
  - 1x master/login node
  - 3x compute nodes, on a
* access to the cluster is only possible via floating IP associated
  with the master node
* compute nodes are connected to an isolated network (without router)
* access to the internet from the compute nodes is allowed through the
  masternode (NAT + firewall)
* optionally: /home is stored on a cinder volume and exported to the
  compute nodes via NFS

At the end of the exercise you will need to provide to the teachers:

* a public IP address accessible from the lab


DoD (Definition of Done)
------------------------

The exercise can be considered completed IF AND ONLY IF:

* the teacher can login to the given IP using user **bofh** with password
  **r00t15n0tthere** and submit a simple job using ``srun`` command.
* the job must be executed on a node different from the login node
* commands ``squeue`` and ``sinfo`` must work and return at least one
  compute node different from the login node.
