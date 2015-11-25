------------------------------
Cinder - Block storage service
------------------------------

As we did for the image node before staring it is good to quickly
check if the remote ssh execution of the commands done in the `all
nodes installation <basic_services.rst#all-nodes-installation>`_ section worked without problems. You can again
verify it by checking the ntp installation.

**Cinder** is the name of the OpenStack block storage service. It
allows manipulation of volumes, volume types (similar to compute
flavors) and volume snapshots.

Note that a volume may only be attached to one instance at a
time. This is not a *shared storage* solution like NFS, where multiple
servers can mount the same filesystem. Instead, it's more like a SAN,
where volumes are created, and then accessed by one single server at a
time, and used as a raw block device.

It is important to say that cinder volumes are usually *persistent*,
so they are never deleted automatically, and must be deleted manually
via web, command line or API.

Volumes created by cinder are served via iSCSI to the compute node,
which will provide them to the VM as regular sata disk. These volumes
can be stored on different backends: LVM (the default one), Ceph,
GlusterFS, NFS or various appliances from IBM, NetApp etc.

Possible usecase cinder volume are:
* as a backend for a database
* as a device to be exported via NFS/Lustre/GlusterFS to other VMs
* as a mean for backing up important data created from within a VM

Cinder is actually composed of different services:

**cinder-api** 

    The cinder-api service is a WSGI app that authenticates and routes
    requests throughout the Block Storage system. It can be used
    directly (via API or via ``cinder`` command line tool) but it is
    also accessed by the ``nova`` service and the horizon web
    interface.

**cinder-scheduler** 

    The cinder-scheduler is responsible for scheduling/routing
    requests to the appropriate volume service. As of Icehouse;
    depending upon your configuration this may be simple round-robin
    scheduling to the running volume services, or it can be more
    sophisticated through the use of the Filter Scheduler. The Filter
    Scheduler is the default in Icehouse and enables filter on things
    like Capacity, Availability Zone, Volume Types and Capabilities as
    well as custom filters.

**cinder-volume** 

    The cinder-volume service is responsible for managing Block
    Storage devices, specifically the back-end devices themselves.

In our setup, we will run all the cinder services on the same machine,
although you can, in principle, spread them over multiple servers.

cinder database and keystone setup
----------------------------------

As usual, we need to create a database on the **db-node** and an user
in keystone.

On the **db-node** create the database and the MySQL user::

    root@db-node:~# mysql -u root -p
    MariaDB [(none)]> CREATE DATABASE cinder;
    MariaDB [(none)]> GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'openstack';
    MariaDB [(none)]> GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'openstack';
    MariaDB [(none)]> FLUSH PRIVILEGES;
    MariaDB [(none)]> exit

On the **auth-node** create a keystone user, a "volume" service and
its endpoint, like we did for the *glance* service. The following
commands assume you already set the environment variables needed to
run keystone without specifying login, password and endpoint all the
times.

First of all we need to create a keystone user for the cinder service, 
associated with the **service** tenant::

    root@auth-node:~# openstack user create --domain default --password-prompt cinder
    User Password:
    Repeat User Password:
    +-----------+----------------------------------+
    | Field     | Value                            |
    +-----------+----------------------------------+
    | domain_id | default                          |
    | enabled   | True                             |
    | id        | 27ad91e85e1c43cc86f04dd544fa1eb8 |
    | name      | cinder                           |
    +-----------+----------------------------------+

Then we need to give admin permissions to it::

    root@auth-node:~# openstack role add --project service --user cinder admin

We need then to create two **volume** service::

    root@auth-node:~# openstack service create --name cinder --description "OpenStack Block Storage" volume
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | OpenStack Block Storage          |
    | enabled     | True                             |
    | id          | 85d16b9e37f441fbb540c30e253e4c69 |
    | name        | cinder                           |
    | type        | volume                           |
    +-------------+----------------------------------+
    root@auth-node:~# openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | OpenStack Block Storage          |
    | enabled     | True                             |
    | id          | 6ca094ab5b7948099deeef9f62e4ca4a |
    | name        | cinderv2                         |
    | type        | volumev2                         |
    +-------------+----------------------------------+


and the related endpoints, using the services' id we just got::
        

   root@auth-node:~# openstack endpoint create --region RegionOne volume public http://volume-node.example.org:8776/v1/%\(tenant_id\)s
   +--------------+------------------------------------------------------+
   | Field        | Value                                                |
   +--------------+------------------------------------------------------+
   | enabled      | True                                                 |
   | id           | 1711ffdd1c364587b3455e62420b66a8                     |
   | interface    | public                                               |
   | region       | RegionOne                                            |
   | region_id    | RegionOne                                            |
   | service_id   | 85d16b9e37f441fbb540c30e253e4c69                     |
   | service_name | cinder                                               |
   | service_type | volume                                               |
   | url          | http://volume-node.example.org:8776/v1/%(tenant_id)s |
   +--------------+------------------------------------------------------+
   root@auth-node:~# openstack endpoint create --region RegionOne volume internal http://volume-node.example.org:8776/v1/%\(tenant_id\)s
   +--------------+------------------------------------------------------+
   | Field        | Value                                                |
   +--------------+------------------------------------------------------+
   | enabled      | True                                                 |
   | id           | fdc1b296eb264286a962ad0b8129c83e                     |
   | interface    | internal                                             |
   | region       | RegionOne                                            |
   | region_id    | RegionOne                                            |
   | service_id   | 85d16b9e37f441fbb540c30e253e4c69                     |
   | service_name | cinder                                               |
   | service_type | volume                                               |
   | url          | http://volume-node.example.org:8776/v1/%(tenant_id)s |
   +--------------+------------------------------------------------------+
   root@auth-node:~# openstack endpoint create --region RegionOne volume admin http://volume-node.example.org:8776/v1/%\(tenant_id\)s
   +--------------+------------------------------------------------------+
   | Field        | Value                                                |
   +--------------+------------------------------------------------------+
   | enabled      | True                                                 |
   | id           | 1fa52d48fc7c442d955c01d510cdb6c5                     |
   | interface    | admin                                                |
   | region       | RegionOne                                            |
   | region_id    | RegionOne                                            |
   | service_id   | 85d16b9e37f441fbb540c30e253e4c69                     |
   | service_name | cinder                                               |
   | service_type | volume                                               |
   | url          | http://volume-node.example.org:8776/v1/%(tenant_id)s |
   +--------------+------------------------------------------------------+

   root@auth-node:~# openstack endpoint create --region RegionOne volumev2 public http://volume-node.example.org:8776/v2/%\(tenant_id\)s
   +--------------+------------------------------------------------------+
   | Field        | Value                                                |
   +--------------+------------------------------------------------------+
   | enabled      | True                                                 |
   | id           | 22e32fcc0b5a4b7d8516fccbb10c6156                     |
   | interface    | public                                               |
   | region       | RegionOne                                            |
   | region_id    | RegionOne                                            |
   | service_id   | 6ca094ab5b7948099deeef9f62e4ca4a                     |
   | service_name | cinderv2                                             |
   | service_type | volumev2                                             |
   | url          | http://volume-node.example.org:8776/v2/%(tenant_id)s |
   +--------------+------------------------------------------------------+
   root@auth-node:~# openstack endpoint create --region RegionOne volumev2 internal http://volume-node.example.org:8776/v2/%\(tenant_id\)s
   +--------------+------------------------------------------------------+
   | Field        | Value                                                |
   +--------------+------------------------------------------------------+
   | enabled      | True                                                 |
   | id           | 44098829c0ba40faae67844f31c185d3                     |
   | interface    | internal                                             |
   | region       | RegionOne                                            |
   | region_id    | RegionOne                                            |
   | service_id   | 6ca094ab5b7948099deeef9f62e4ca4a                     |
   | service_name | cinderv2                                             |
   | service_type | volumev2                                             |
   | url          | http://volume-node.example.org:8776/v2/%(tenant_id)s |
   +--------------+------------------------------------------------------+
   root@auth-node:~# openstack endpoint create --region RegionOne volumev2 admin http://volume-node.example.org:8776/v2/%\(tenant_id\)s
   +--------------+------------------------------------------------------+
   | Field        | Value                                                |
   +--------------+------------------------------------------------------+
   | enabled      | True                                                 |
   | id           | 6035ea09f6ef426cb84543b0ed439b91                     |
   | interface    | admin                                                |
   | region       | RegionOne                                            |
   | region_id    | RegionOne                                            |
   | service_id   | 6ca094ab5b7948099deeef9f62e4ca4a                     |
   | service_name | cinderv2                                             |
   | service_type | volumev2                                             |
   | url          | http://volume-node.example.org:8776/v2/%(tenant_id)s |
   +--------------+------------------------------------------------------+


Please note that the URLs need to be quoted using the (') character
(single quote) otherwise the shell will interpret the dollar sign ($)
present in the url.

We should now have 12 endpoints on keystone::
   
   root@auth-node:~# openstack endpoint list 
   +----------------------------------+-----------+--------------+--------------+---------+-----------+------------------------------------------------------+
   | ID                               | Region    | Service Name | Service Type | Enabled | Interface | URL                                                  |
   +----------------------------------+-----------+--------------+--------------+---------+-----------+------------------------------------------------------+
   | 0afed953c2fd40b69d7cd6f55e88dd95 | RegionOne | keystone     | identity     | True    | admin     | http://auth-node.example.org:35357/v2.0              |
   | 0bc0ce6e1c484b349c5c29884c021e4e | RegionOne | glance       | image        | True    | internal  | http://image-node.example.org:9292                   |
   | 1711ffdd1c364587b3455e62420b66a8 | RegionOne | cinder       | volume       | True    | public    | http://volume-node.example.org:8776/v1/%(tenant_id)s |
   | 1fa52d48fc7c442d955c01d510cdb6c5 | RegionOne | cinder       | volume       | True    | admin     | http://volume-node.example.org:8776/v1/%(tenant_id)s |
   | 22e32fcc0b5a4b7d8516fccbb10c6156 | RegionOne | cinderv2     | volumev2     | True    | public    | http://volume-node.example.org:8776/v2/%(tenant_id)s |
   | 44098829c0ba40faae67844f31c185d3 | RegionOne | cinderv2     | volumev2     | True    | internal  | http://volume-node.example.org:8776/v2/%(tenant_id)s |
   | 4e2d0570fd434ddbab7b254c1c3b4524 | RegionOne | keystone     | identity     | True    | public    | http://auth-node.example.org:5000/v2.0               |
   | 6035ea09f6ef426cb84543b0ed439b91 | RegionOne | cinderv2     | volumev2     | True    | admin     | http://volume-node.example.org:8776/v2/%(tenant_id)s |
   | 7d02f87f78a64a0591e5ea2378dc9b09 | RegionOne | glance       | image        | True    | public    | http://image-node.example.org:9292                   |
   | c1350cde50af4482b2ab3b79588ce457 | RegionOne | glance       | image        | True    | admin     | http://image-node.example.org:9292                   |
   | dd7fbe5f6e064d5d9e2d6b3ec84c445e | RegionOne | keystone     | identity     | True    | internal  | http://auth-node.example.org:5000/v2.0               |
   | fdc1b296eb264286a962ad0b8129c83e | RegionOne | cinder       | volume       | True    | internal  | http://volume-node.example.org:8776/v1/%(tenant_id)s |
   +----------------------------------+-----------+--------------+--------------+---------+-----------+------------------------------------------------------+
   
Add a volume to volume-node instance
------------------------------------

You can do this via web interface::

    user@ubuntu:~$ nova volume-create --display-name cinder 100
    +---------------------+--------------------------------------+
    | Property            | Value                                |
    +---------------------+--------------------------------------+
    | attachments         | []                                   |
    | availability_zone   | nova                                 |
    | bootable            | false                                |
    | created_at          | 2015-05-02T17:51:39.022417           |
    | display_description | -                                    |
    | display_name        | cinder                               |
    | encrypted           | False                                |
    | id                  | e539ddc6-f31f-406a-b534-6fc2af1c231a |
    | metadata            | {}                                   |
    | size                | 100                                  |
    | snapshot_id         | -                                    |
    | source_volid        | -                                    |
    | status              | creating                             |
    | volume_type         | None                                 |
    +---------------------+--------------------------------------+

    user@ubuntu:~$ nova volume-attach volume-node e539ddc6-f31f-406a-b534-6fc2af1c231a
    +----------+--------------------------------------+
    | Property | Value                                |
    +----------+--------------------------------------+
    | device   | /dev/vdb                             |
    | id       | e539ddc6-f31f-406a-b534-6fc2af1c231a |
    | serverId | d4b8678e-e5d4-462c-89bb-ee0278cf70be |
    | volumeId | e539ddc6-f31f-406a-b534-6fc2af1c231a |
    +----------+--------------------------------------+

basic configuration
-------------------

Let's now go back to the  **volume-node** and install the cinder
packages::

    root@volume-node:~# cinder-api cinder-scheduler cinder-volume python-mysqldb  python-cinderclient lvm2 

We will configure cinder in order to create volumes using LVM, but in
order to do that we have to provide a volume group called
``cinder-volume`` (you can use a different name, but you have to
update the cinder configuration file).

At this point, you should create a volume in `cloud-test` and attach
it to the **volume-node** machine...

The **volume-node** machine has one more disk (``/dev/vdb``) which
we will use for LVM. You can either partition this disk and use those
partitions to create the volume group, or use the whole disk. In our
setup, to keep things simple, we will use the whole disk, so we are
going to:

Create a physical device on the ``/dev/vdb`` disk::

    root@volume-node:~# pvcreate /dev/vdb
      Physical volume "/dev/vdb" successfully created

create a volume group called **cinder-volumes** on it::

    root@volume-node:~# vgcreate cinder-volumes /dev/vdb
      Volume group "cinder-volumes" successfully created

check that the volume group has been created::

    root@volume-node:~# vgdisplay cinder-volumes
      --- Volume group ---
      VG Name               cinder-volumes
      System ID             
      Format                lvm2
      Metadata Areas        1
      Metadata Sequence No  1
      VG Access             read/write
      VG Status             resizable
      MAX LV                0
      Cur LV                0
      Open LV               0
      Max PV                0
      Cur PV                1
      Act PV                1
      VG Size               1.95 GiB
      PE Size               4.00 MiB
      Total PE              499
      Alloc PE / Size       0 / 0   
      Free  PE / Size       499 / 1.95 GiB
      VG UUID               NGrgtl-thWL-4icP-r42k-vLnk-PjDV-mHmEkR

cinder configuration
--------------------

..
   In file ``/etc/cinder/api-paste.ini`` edit the **filter:authtoken**
   section and ensure that information about the keystone user and
   endpoint are correct, specifically the options ``service_host``,
   ``admin_tenant_name``, ``admin_user`` and ``admin_password``::

       [filter:authtoken]
       paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
       service_protocol = http
       service_host = 10.0.0.4
       service_port = 5000
       auth_host = 10.0.0.4
       auth_port = 35357
       auth_protocol = http
       admin_tenant_name = service
       admin_user = cinder
       admin_password = cinderServ
       signing_dir = /var/lib/cinder

Now let's configure Cinder. The main file is
``/etc/cinder/cinder.conf``::

    [DEFAULT]
    [...]
    rpc_backend = rabbit
    auth_strategy = keystone
    my_ip = <IP_OF_THE_VOLUME_NODE> 
    verbose=True 
    enabled_backends = lvm
    glance_host=volume-node.example.org
    
    [oslo_messaging_rabbit]
    rabbit_host = db-node
    rabbit_userid = openstack
    rabbit_password = openstack
    
    [database]
    connection = mysql+pymysql://cinder:openstack@db-node/cinder

    [keystone_authtoken]
    auth_uri = http://auth-node.example.org:5000
    auth_url = http://auth-node.example.org:35357
    auth_plugin = password
    project_domain_id = default
    user_domain_id = default
    project_name = service
    username = cinder
    password = openstack

    [oslo_concurrency]
    lock_path = /var/lib/cinder/tm

    [lvm]
    volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
    volume_group = cinder-volumes
    iscsi_protocol = iscsi
    iscsi_helper = tgtadm

.. also needed 
   rabbit_userid = openstack

.. Default values for all the other options should be fine. Please note
   that here you can change the name of the LVM volume group to use, and
   the default name to be used when creating volumes.

.. iscsi_ip_address is needed otherwise, in our case, it will try to
   connect using 192.168. network which is not reachable from the
   OpenStack VMs.

.. In some cases, you might need to define the ``iscsi_ip_address``,
   which is the IP address used to serve the volumes via iSCSI. This IP
   must be reachable by the compute nodes, and in some cases you may have
   a different network for this kind of traffic.::
   [DEFAULT]
   [...]
   iscsi_ip_address = 10.0.0.8

.. Finally, let's add a section for `keystone` authentication::
    [keystone_authtoken]
    identity_uri = http://auth-node.example.org:35357
    admin_tenant_name = service
    admin_user = cinder
    admin_password = openstack

.. is already set to tgtadm in IceHouse``iscsi_helper``.

Populate the cinder database::

    root@volume-node:~# /bin/sh -c "cinder-manage db sync" cinder 

    2014-08-21 14:19:13.676 3576 INFO migrate.versioning.api [-] 0 -> 1... 
    ....
    2014-08-21 14:19:19.168 3576 INFO migrate.versioning.api [-] 3 -> 4... 
    2014-08-21 14:19:20.270 3576 INFO 004_volume_type_to_uuid [-] Created foreign key volume_type_extra_specs_ibfk_1
    2014-08-21 14:19:20.548 3576 INFO migrate.versioning.api [-] 5 -> 6... 
    ....
    2014-08-21 14:19:25.102 3576 INFO migrate.versioning.api [-] 20 -> 21... 
    2014-08-21 14:19:25.184 3576 INFO 021_add_default_quota_class [-] Added default quota class data into the DB.
    ....
    2014-08-21 14:19:25.395 3576 INFO migrate.versioning.api [-] done


Restart cinder services::

    root@volume-node:~# for serv in cinder-{api,volume,scheduler}; do service $serv restart; done
    root@volume-node:~# service tgt restart

Testing cinder
--------------

Cinder command line tool also allow you to pass user, password, tenant
name and authentication URL both via command line options or
environment variables. In order to make the commands easier to read we
are going to set the environment variables and run cinder without
options::

    root@volume-node:~# export OS_USERNAME=admin
    root@volume-node:~# export OS_PASSWORD=openstack
    root@volume-node:~# export OS_TENANT_NAME=admin
    root@volume-node:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0

Test cinder by creating a volume::

    root@volume-node:~# cinder create --display-name test 1
    +---------------------------------------+--------------------------------------+
    |                Property               |                Value                 |
    +---------------------------------------+--------------------------------------+
    |              attachments              |                  []                  |
    |           availability_zone           |                 nova                 |
    |                bootable               |                false                 |
    |          consistencygroup_id          |                 None                 |
    |               created_at              |      2015-11-25T09:39:58.000000      |
    |              description              |                 None                 |
    |               encrypted               |                False                 |
    |                   id                  | d8047e68-ee9b-4ab5-a152-70b755ab3844 |
    |                metadata               |                  {}                  |
    |            migration_status           |                 None                 |
    |              multiattach              |                False                 |
    |                  name                 |                 test                 |
    |         os-vol-host-attr:host         |                 None                 |
    |     os-vol-mig-status-attr:migstat    |                 None                 |
    |     os-vol-mig-status-attr:name_id    |                 None                 |
    |      os-vol-tenant-attr:tenant_id     |   3aab8a31a7124de690032b398a83db37   |
    |   os-volume-replication:driver_data   |                 None                 |
    | os-volume-replication:extended_status |                 None                 |
    |           replication_status          |               disabled               |
    |                  size                 |                  1                   |
    |              snapshot_id              |                 None                 |
    |              source_volid             |                 None                 |
    |                 status                |               creating               |
    |                user_id                |   11a4e8d058ad40239f9ccde710cdc527   |
    |              volume_type              |                 None                 |
    +---------------------------------------+--------------------------------------+


**NOTE**: at this point, you will probably get an error. Please, check
the logs and try to find out what the problem is, and how to solve it.

Shortly after, a ``cinder list`` command should show you the newly
created volume::

    root@volume-node:~# cinder list
    +--------------------------------------+-----------+------------------+------+------+-------------+----------+-------------+-------------+
    |                  ID                  |   Status  | Migration Status | Name | Size | Volume Type | Bootable | Multiattach | Attached to |
    +--------------------------------------+-----------+------------------+------+------+-------------+----------+-------------+-------------+
    | d8047e68-ee9b-4ab5-a152-70b755ab3844 | available |        -         | test |  1   |      -      |  false   |    False    |             |
    +--------------------------------------+-----------+------------------+------+------+-------------+----------+-------------+-------------+
  
You can easily check that a new LVM volume has been created::

    root@volume-node:~# lvdisplay /dev/cinder-volumes
      --- Logical volume ---
      LV Name                /dev/cinder-volumes/volume-4d04a3d2-0fa7-478d-9314-ca6f52ef08d5
      VG Name                cinder-volumes
      LV UUID                RRGmob-jMZC-4Mdm-kTBv-Qc6M-xVsC-gEGhOg
      LV Write Access        read/write
      LV Status              available
      # open                 1
      LV Size                1.00 GiB
      Current LE             256
      Segments               1
      Allocation             inherit
      Read ahead sectors     auto
      - currently set to     256
      Block device           252:0

.. **tgtadm DOES NOT SHOW ANY OUTPUT WHEN THE VOLUME IS NOT ATTACHED, MOVE TO THE TESTING SECTION** 

..
   To show if the volume is actually served via iscsi you can run::

      root@volume-node:~# tgtadm  --lld iscsi --op show --mode target
      Target 1: iqn.2010-10.org.openstack:volume-4d04a3d2-0fa7-478d-9314-ca6f52ef08d5
          System information:
              Driver: iscsi
              State: ready
          I_T nexus information:
          LUN information:
              LUN: 0
                  Type: controller
                  SCSI ID: IET     00010000
                  SCSI SN: beaf10
                  Size: 0 MB, Block size: 1
                  Online: Yes
                  Removable media: No
                  Readonly: No
                  Backing store type: null
                  Backing store path: None
                  Backing store flags: 
              LUN: 1
                  Type: disk
                  SCSI ID: IET     00010001
                  SCSI SN: beaf11
                  Size: 1074 MB, Block size: 512
                  Online: Yes
                  Removable media: No
                  Readonly: No
                  Backing store type: rdwr
                  Backing store path: /dev/cinder-volumes/volume-4d04a3d2-0fa7-478d-9314-ca6f52ef08d5
                  Backing store flags: 
          Account information:
          ACL information:
              ALL


Since the volume is not used by any VM, we can delete it with the
``cinder delete`` command (you can use the volume `Display Name`
instead of the volume `id` if this is uniqe)::

    root@volume-node:~# cinder delete d8047e68-ee9b-4ab5-a152-70b755ab3844 

Deleting the volume can take some time::

    Request to delete volume d8047e68-ee9b-4ab5-a152-70b755ab3844 has been accepted.
    root@volume-node:~# cinder list
    +--------------------------------------+----------+------------------+------+------+-------------+----------+-------------+-------------+
    |                  ID                  |  Status  | Migration Status | Name | Size | Volume Type | Bootable | Multiattach | Attached to |
    +--------------------------------------+----------+------------------+------+------+-------------+----------+-------------+-------------+
    | d8047e68-ee9b-4ab5-a152-70b755ab3844 | deleting |        -         | test |  1   |      -      |  false   |    False    |             |
    +--------------------------------------+----------+------------------+------+------+-------------+----------+-------------+-------------+


After a while, the volume is deleted, and LV is deleted::

    root@volume-node:~# cinder list
    root@volume-node:~# cinder list 
    +----+--------+------------------+------+------+-------------+----------+-------------+-------------+
    | ID | Status | Migration Status | Name | Size | Volume Type | Bootable | Multiattach | Attached to |
    +----+--------+------------------+------+------+-------------+----------+-------------+-------------+
    +----+--------+------------------+------+------+-------------+----------+-------------+-------------+

    root@volume-node:~# lvs
      LV     VG        Attr      LSize Pool Origin Data%  Move Log Copy%  Convert
      root   golden-vg -wi-ao--- 7.76g                                           
      swap_1 golden-vg -wi-ao--- 2.00g 

`Next: nova-api - Compute service <nova_api.rst>`_

..
   **AGAIN MOVE TO THE TESTING SECTION, AS HERE IS NOT RELEVANT**::
       
       root@volume-node:~# tgtadm  --lld iscsi --op show --mode target

       root@volume-node:~# lvdisplay 


