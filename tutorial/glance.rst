----------------------
Glance - Image Service
----------------------

**Glance** is the name of the image service of OpenStack. It is
responsible for storing the images that will be used as templates to
start the instances. We will use the default configuration and
only do the minimal changes to match our configuration.

Glance is actually composed of two different services:

* **glance-api** accepts API calls for dicovering the available
  images and their metadata and is used also to retrieve them. It
  supports two protocol versions: v1 and v2; when using v1, it does
  not directly access the database but instead it talks to the
  **glance-registry** service

* **glance-registry** used by **glance-api** to actually retrieve image
  metadata when using the old v1 protocol.


database and keystone setup
---------------------------

Similarly to what we did for the keystone service, also for the glance
service we need to create a database and a pair of user and password
for it.

On the **db-node** create the database and the MySQL user::

    root@db-node:~# mysql -u root -p
    MariaDB [(none)]> CREATE DATABASE glance;
    MariaDB [(none)]> GRANT ALL ON glance.* TO 'glance'@'image-node' IDENTIFIED BY 'openstack';
    MariaDB [(none)]> FLUSH PRIVILEGES;
    MariaDB [(none)]> exit;

On the **auth-node** instead we need to create an **image** service
and an endpoint associated with it. The following commands assume you
already set the environment variables needed to run keystone without
specifying login, password and endpoint all the times.

First of all we create a `glance` user for keystone, belonging to the `service` 
project. You could also use the `admin` user, but it's better not to mix things::

    user@ubuntu:~$ openstack user create --password openstack glance
    +-----------+----------------------------------+
    | Field     | Value                            |
    +-----------+----------------------------------+
    | domain_id | default                          |
    | enabled   | True                             |
    | id        | 9939e3c4b8e8454a96682158fc7257d8 |
    | name      | glance                           |
    +-----------+----------------------------------+

Then we need to give admin permissions to it::

    user@ubuntu:~$ openstack role add --project service --user glance admin 

Note that the command does not print any confirmation on successful completion.
Please note that we could have created only one user for all the services, but this is a cleaner solution.

We need then to create the **image** service::

    user@ubuntu:~$ openstack service create --name glance --description "OpenStack Image service" image
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | OpenStack Image service          |
    | enabled     | True                             |
    | id          | 572baa15763a44729f7ffe63e0f1d585 |
    | name        | glance                           |
    | type        | image                            |
    +-------------+----------------------------------+

and the related endpoints. Now, about that: the version of openstack
client you install on your node is a bit newer than the one installed
via debian, so the syntax is a bit different::

    user@ubuntu:~$ openstack endpoint create --region RegionOne \
      image --publicurl http://<PUBLIC_IP_OF_BASTION>:9292 \
      --internalurl http://image-node:9292 \
      --adminurl http://<PUBLIC_IP_OF_BASTION>:9292
    +--------------+----------------------------------+
    | Field        | Value                            |
    +--------------+----------------------------------+
    | adminurl     | http://130.60.24.120:9292        |
    | id           | ef0f5d15de354874b23d1b2f90ad4838 |
    | internalurl  | http://image-node:9292           |
    | publicurl    | http://130.60.24.120:9292        |
    | region       | RegionOne                        |
    | service_id   | bf291334f2c64260a633a5cb8a435948 |
    | service_name | glance                           |
    | service_type | image                            |
    +--------------+----------------------------------+

installation and configuration
------------------------------

On the **image-node** install the **glance** package::

    root@image-node:~$ apt-get -y install glance python-glanceclient 

To configure the glance service we need to edit a few files in ``/etc/glance``:

Information on how to connect to the MySQL database is stored in the
``/etc/glance/glance-api.conf`` and ``/etc/glance/glance-registry.conf``
files.  The syntax is similar to the one used in the
``/etc/keystone/keystone.conf`` file, the name of the option is
``connection`` again, in ``[database]`` section. Please edit both
files and change it to (if it's not there, add it to the section)::

    [database]
    ...
    connection = mysql+pymysql://glance:openstack@db-node/glance 

The Image Service has to be configured to use the message broker. Configuration
information is stored in ``/etc/glance/glance-api.conf``. Please open the file 
and change as follows in the ``[DEFAULT] section``::

     [DEFAULT]
     ...
     rpc_backend = rabbit
     rabbit_host = db-node
     rabbit_userid = openstack
     rabbit_password = openstack

.. NOTE: I don't think glance is sending notifications at all, as they
   are not needed very often. I think it's used only when you want to
   be notified when an image have been updated.

   Also check `notification_driver` option

Note that by default RabbitMQ is not used by glance, because there
isn't much communication between glance and other services that cannot
pass through the public API. However, if you define this and set the
``notification_driver`` option to ``rabbit``, you can receive
notifications for image creation/deletion.

Also, we need to adjust the ``[keystone_authtoken]`` section so that
it matches the values we used when we created the keystone **glance**.

On both files,  ``glance-api.conf`` and
``glance-registry.conf``, ensure the following are set::

    [keystone_authtoken]
    auth_uri = http://auth-node:5000
    auth_url = http://auth-node:35357
    auth_plugin = password
    project_domain_id = default
    user_domain_id = default
    project_name = service
    username = glance
    password = openstack

We need to specify which paste pipeline we are using. We are not entering into details
here, just check that the following option is present again in both ``glance-api.conf`` 
and ``glance-registry.conf``::

    [paste_deploy]
    flavor = keystone

Finally again in both ``glance-api.conf`` and ``glance-registry.conf`` set::

    notification_driver = noop
    verbose = True

Inside the ``[glance-store]]`` of the ``glance-api.conf`` file please change
the following entries::

    default_store = file
    filesystem_store_datadir = /var/lib/glance/images/

.. Grizzly note:
   Very interesting: we misspelled the password here, but we only get
   errors when getting the list of VM from horizon. Booting VM from
   nova actually worked!!! 
   
   Found the following explanation here: http://bcwaldon.cc/
   
   glance-registry vs glance-api
   The v1 and v2 Images APIs were implemented with seperate paths to
   the Glance database. The first of which proxies queries through a subsequent
   HTTP service (glance-registry) while the second talks directly to the database. 
   As these two APIs should be talking to an equivalent system, we will be realigning
   their internal paths to talk through the service layer (created with the domain object model)
   directly to the database, effectively deprecating the glance-registry service.


Like we did with keystone, we need to populate the glance database::

    root@image-node:~# glance-manage db_sync

Now we are ready to restart the glance services::

    root@image-node:~# restart glance-api restart
    root@image-node:~# restart glance-registry restart

From your laptop you should now be able to access glance::

    user@ubuntu:~$ glance image-list
    +----+------+-------------+------------------+------+--------+
    | ID | Name | Disk Format | Container Format | Size | Status |
    +----+------+-------------+------------------+------+--------+
    +----+------+-------------+------------------+------+--------+

Testing
-------

First of all, let's download a very small test image::

    user@ubuntu:~$ wget http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img

.. Note that if the --os-endpoint-type is not specified glance will try to use 
   publicurl and if the 130.60.24.120 is not in /etc/hosts an error 
   will be issued.  

(You can also download an Ubuntu distribution from the official
`Ubuntu Cloud Images <https://cloud-images.ubuntu.com/>`_ website)

The command line tool to manage images is ``glance``. Uploading an image is easy::

   user@ubuntu:~$ glance image-create \
     --name cirros-0.3.3 \
     --visibility public \
     --container-format bare \
     --disk-format qcow2 \
     --progress \
     --file cirros-0.3.3-x86_64-disk.img
   +------------------+--------------------------------------+
   | Property         | Value                                |
   +------------------+--------------------------------------+
   | checksum         | 133eae9fb1c98f45894a4e60d8736619     |
   | container_format | bare                                 |
   | created_at       | 2015-11-24T14:37:48Z                 |
   | disk_format      | qcow2                                |
   | id               | 902f4b61-e802-4321-a304-28efdadbad11 |
   | min_disk         | 0                                    |
   | min_ram          | 0                                    |
   | name             | cirros-0.3.3                         |
   | owner            | 705ab94a4803444bba42eb2f22de8679     |
   | protected        | False                                |
   | size             | 13200896                             |
   | status           | active                               |
   | tags             | []                                   |
   | updated_at       | 2015-11-24T14:37:48Z                 |
   | virtual_size     | None                                 |
   | visibility       | public                               |
   +------------------+--------------------------------------+

.. Maybe it is worthy to explain all the options we use: 
   * *--name* is the name which will be seen in the Horizon UI 
   * *--is-public* is a binary option which specifies if the uploaded
     image should be publicaly available/visible/used or access should
     be limited to *all* the users of the tenant from where the user 
     uploading the images comes.
   * *--container-format* is the container format of image. It refers to 
     whether the virtual machine image is in a file format that also contains
     metadata about the actual virtual machine. Note that the container format
     string is not currently used by Glance or other OpenStack components, so it
     is safe to simply specify bare as the container format if you are unsure. 
     Acceptable formats: ami, ari, aki, bare, and ovf.
   * *--disk-format* is the disk format of a virtual machine image is the format of
     the underlying disk image. Virtual appliance vendors have different formats for
     laying out the information contained in a virtual machine disk image.  
     Acceptable formats: raw, vhd, vmdk, vdi, iso, qcow2, aki, ari, ami.  

Using ``glance`` command you can also list the images currently
uploaded on the image store::

   user@ubuntu:~$ glance image-list
   +--------------------------------------+--------------+
   | ID                                   | Name         |
   +--------------------------------------+--------------+
   | 902f4b61-e802-4321-a304-28efdadbad11 | cirros-0.3.3 |
   +--------------------------------------+--------------+


The cirros image we uploaded before, having an image id of
``902f4b61-e802-4321-a304-28efdadbad11``, will be found in::

    root@image-node:~# ls -l /var/lib/glance/images/902f4b61-e802-4321-a304-28efdadbad11
    -rw-r----- 1 glance glance 9761280 Apr 24 16:38 /var/lib/glance/images/902f4b61-e802-4321-a304-28efdadbad11

You can easily find ready-to-use images on the web. An image for the
`Ubuntu Server 14.04 "Precise" (amd64)
<http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img>`_
can be found at the `Ubuntu Cloud Images archive
<http://cloud-images.ubuntu.com/>`_, you can download it and upload
using glance as we did before.

If you want to get further information about `qcow2` images, you will
need to install `qemu-utils` package and run `qemu-img info <image
name`:: 


    root@image-node:~# apt-get install -y qemu-utils
    [...]
    root@image-node:~# qemu-img info /var/lib/glance/images/902f4b61-e802-4321-a304-28efdadbad11
    image: /var/lib/glance/images/902f4b61-e802-4321-a304-28efdadbad11
    file format: qcow2
    virtual size: 39M (41126400 bytes)
    disk size: 9.3M
    cluster_size: 65536
    Format specific information:
    compat: 0.10


Further improvements
--------------------

By default glance will store all the images as files in
``/var/lib/glance/images``, but other options are available,
including:

* S3 (Amazon object storage service)
* Swift (OpenStack object storage service)
* RBD (Ceph's remote block device)
* Cinder (Yes, your images can be volumes on cinder!)
* etc...
  
This is changed by the option ``default_store`` in the
``/etc/glance/glance-api.conf`` configuration file, and depending on
the type of store you use, more options are availble to configure it,
like the path for the *filesystem* store, or the access and secret
keys for the s3 store, or rdb configuration options.

Please refer to the official documentation to change these values.

Another improvement you may want to consider in a production environment
is the Glance Image Cache. This option will create a local cache in
the glance server, in order to improve the download speed for most
used images, and reduce the load on the storage backend, possibly
putting multiple glance servers behind a load-balancer like haproxy.

More detailed information can be found `here <http://docs.openstack.org/developer/glance/cache.html>`_  

`Next: Cinder - Block storage service <cinder.rst>`_
