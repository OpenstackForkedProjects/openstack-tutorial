--------------------------
Keystone: Identity service
--------------------------

The **auth-node** will run *keystone*, also known as *identity service*.

Keystone performs two main tasks:

* stores information about Authentication and Authorizations (*users*,
  *passwords*, *authorization tokens*, *projects* (also known as
  *tenants*) and *roles*
* stores information about available *services* and the URI of the
  *endpoints*.

Every OpenStack client and service needs to access keystone, first to
discover other services, and then to authenticate and authorize each
request. It is thus the main endpoint of an OpenStack installation, so
that by giving the URL of the keystone service, a client can get all
the information it needs to operate on that specific cloud.

In order to facilitate your understanding during this part we add the 
definitions of some termins you may want to give a glimpse while we
are going on:

* *User* is a user of OpenStack.
* *Service catalog* provides a catalog of available OpenStack services with their APIs.
* *Token* is an arbitrary bit of text used to access resources. Each token has a
  scope which describes which resource are accessible with it.
* *Project* A container which is used to group or isolate resources and/or identify objects.
  Depending on the case a tenant may map to customer, account, organization or project.
* *Service* is an OpenStack service, such as Compute, Image service, etc.
* *Endpoint* is a network-accessible address (URL), from where you access an OpenStack service.
* *Role* is a presonality that an user assumes that enables him to perform a specific set of
  operations, basically a set of rights and privileges (usually inside a tenant for example).  

Keystone
--------

Keystone stores information about different, independent services:

* users, passwords and tenants
* authorization tokens
* service catalog

These can be stored on different locations, for instance you can store
tokens using `memcached
<http://memcached.org/>`_, user/password/tenant informations on LDAP,
and the service catalog on a file.

However, the easiest way to configure keystone and possibly the most
common is to use MariaDB for all of them, therefore this is how we are
going to configure it.

On the **db-node** you need to create a database and a pair of user
and password for the keystone service::

    root@db-node:~# mysql -u root -p
    MariaDB [(none)]> CREATE DATABASE keystone;
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'openstack';
    MariaDB [(none)]> FLUSH PRIVILEGES;
    MariaDB [(none)]> exit

Please note that almost every OpenStack service will need a private
database, which means that we are going to run commands similar to the
previous one a lot of times.

In Kilo and Liberty the eventlet is deprecated in favor of a separate web server 
with WSGI extentions. We will use the mod_wsgi module of Apache HTTP to provide
requests on port 5000 and 35357. 

Go to the **auth-node** and as a first step disable the keystone service for starting 
the automatically after installation:: 

    root@auth-node:~# echo "manual" > /etc/init/keystone.override

Proceed with installing the keystone and all the needed packages:: 

    root@auth-node:~# apt-get install keystone python-openstackclient apache2 libapache2-mod-wsgi memcached python-memcache

This step installes also the `keystone-pythonclient` package (as adependency of the keystone package)
which is the CLI for interactig with keystone.

..
   **NOTE** Installing keystone *without* installing also
   python-mysqldb can lead to the following error:
   **014-08-20 15:33:20.956 13334 CRITICAL keystone [-] ImportError: No module named MySQLdb**

The default installation will create an SQLite database in
``/var/lib/keystone/keystone.db``, but as we already stated this is
not going to be used and can be safely removed.::

    root@auth-node:~# rm /var/lib/keystone/keystone.db
 
In order to use the MariaDB database we just created, update the value of the ``connection`` option in
section ``[database]`` of the ``/etc/keystone/keystone.conf`` file, in order to match the hostname,
database name, user and password we used. The syntax of this option is::

    connection = <protocol>://<user>:<password>@<host>/<db_name>

So in our case you need to replace the default option with::

    connection = mysql+pymysql://keystone:openstack@db-node/keystone

Now you are ready to bootstrap the keystone database using the following command::

    root@auth-node:~# keystone-manage db_sync

    .. ANTONIO: Trying to run it as regular user, it's probably OK
    .. root@auth-node:~# su -s /bin/sh -c "keystone-manage db_sync" keystone

Configure the Apache HTTP server by opening /etc/apache2/apache2.conf and change the
``ServerName controller`` to the hostname of the controller (auth-node) in our case:
``ServerName auth-node.example.org``.

Create the ``/etc/apache2/sites-available/wsgi-keystone.conf`` with
the following contents::

    Listen 5000
    Listen 35357
    
    <VirtualHost *:5000>
        WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
        WSGIProcessGroup keystone-public
        WSGIScriptAlias / /usr/bin/keystone-wsgi-public
        WSGIApplicationGroup %{GLOBAL}
        WSGIPassAuthorization On
        <IfVersion >= 2.4>
          ErrorLogFormat "%{cu}t %M"
        </IfVersion>
        ErrorLog /var/log/apache2/keystone.log
        CustomLog /var/log/apache2/keystone_access.log combined
    
        <Directory /usr/bin>
            <IfVersion >= 2.4>
                Require all granted
            </IfVersion>
            <IfVersion < 2.4>
                Order allow,deny
                Allow from all
            </IfVersion>
        </Directory>
    </VirtualHost>
    
    <VirtualHost *:35357>
        WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
        WSGIProcessGroup keystone-admin
        WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
        WSGIApplicationGroup %{GLOBAL}
        WSGIPassAuthorization On
        <IfVersion >= 2.4>
          ErrorLogFormat "%{cu}t %M"
        </IfVersion>
        ErrorLog /var/log/apache2/keystone.log
        CustomLog /var/log/apache2/keystone_access.log combined
    
        <Directory /usr/bin>
            <IfVersion >= 2.4>
                Require all granted
            </IfVersion>
            <IfVersion < 2.4>
                Order allow,deny
                Allow from all
            </IfVersion>
        </Directory>
    </VirtualHost> 

.. *

At the end enable the Identity service virtual hosts and reload apache
configuration::

    root@auth-node:~# a2ensite wsgi-keystone
    root@auth-node:~# service apache2 reload

Keystone by default listens to two different ports::

    root@auth-node:~#  netstat -tnlp
    Active Internet connections (only servers)
    Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
    tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1056/sshd       
    tcp        0      0 127.0.0.1:11211         0.0.0.0:*               LISTEN      3294/memcached  
    tcp6       0      0 :::22                   :::*                    LISTEN      1056/sshd       
    tcp6       0      0 :::35357                :::*                    LISTEN      8597/apache2    
    tcp6       0      0 :::5000                 :::*                    LISTEN      8597/apache2    
    tcp6       0      0 :::80                   :::*                    LISTEN      8597/apache2 

.. ANTONIO: This is not true: even if it says ::::5000, it's actually
.. listening on both IPv4 and IPv6

.. As you can see apache2 is listening using only over tcp6, in order to
.. fix this you have to disable ipv6 in ``/etc/sysctl.conf`` by adding
.. the line: ``net.ipv6.conf.all.disable_ipv6 = 1`` and load the
.. changes


..     root@auth-node:~# sysctl -p
..     root@auth-node:~# service apache2 restart

..
   **NOTE:** At the time of writing (01-08-2014), in Ubuntu 14.40
   keystone does not write to the log file in
   ``/var/log/keystone/keystone.log``. In order to enable logging, ensure
   the following configuration option is defined in
   ``/etc/keystone/keystone.conf``::

       log_file = /var/log/keystone/keystone.log

By default, only CRITICAL, ERROR and WARNING messages are logged. To
also log INFO messages, add option::

    verbose = True

while to enable also DEBUG messages, add::

    debug = True


The chicken and egg problem
---------------------------

In order to create users, projects or roles in keystone you need to
access it using an administrative user (which is not automatically
created at the beginning), or you can also use the "*admin token*", a
shared secret that is stored in the keystone configuration file and
can be used to create the initial administrator password.

The default admin token is ``ADMIN``, but you can (and you **should**,
in a production environment) update it by changing the ``admin_token``
option in the ``/etc/keystone/keystone.conf`` file.

Apache listens on two different ports, one (5000) is for public access,
while the other (35357) is for administrative access. You will usually access
the public one but when using the admin token you can only use the
administrative one.

To specify the admin token and endpoint (or user, password and
endpoint) you can either use the keystone command line options or set
some environment variables. Please note that this behavior is common
to all OpenStack command line tools, although the syntax and the
command line options may change.

In our case, since we don't have an admin user yet and we need to use
the admin token, we will set the following environment variables::

    root@auth-node:~# export OS_TOKEN=ADMIN
    root@auth-node:~# export OS_URL=http://auth-node:35357/v3 
    root@auth-node:~# export OS_IDENTITY_API_VERSION=3 


Creation of the admin user
--------------------------

In order to work with keystone we have to create an admin user and
a few basic projects and roles.

We will start by creating two keystone projects: **admin** and
**service**. The first one is used for the admin user, while the
second one is used for the users we will create for the various
services (image, volume, nova etc...). The following commands will
work assuming you already set the correct environment variables::

    root@auth-node:~# openstack project create --domain default --description "Admin Project" admin 
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | Admin Project                    |
    | domain_id   | default                          |
    | enabled     | True                             |
    | id          | 3aab8a31a7124de690032b398a83db37 |
    | is_domain   | False                            |
    | name        | admin                            |
    | parent_id   | None                             |
    +-------------+----------------------------------+ 

    root@auth-node:~# openstack project create --domain default --description='Service Project' service
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | Service Project                  |
    | domain_id   | default                          |
    | enabled     | True                             |
    | id          | 705ab94a4803444bba42eb2f22de8679 |
    | is_domain   | False                            |
    | name        | service                          |
    | parent_id   | None                             |
    +-------------+----------------------------------+


Create the **admin** user::

    root@auth-node:~# openstack user create --password admin admin
    +-----------+----------------------------------+
    | Field     | Value                            |
    +-----------+----------------------------------+
    | domain_id | default                          |
    | enabled   | True                             |
    | id        | 11a4e8d058ad40239f9ccde710cdc527 |
    | name      | admin                            |
    +-----------+----------------------------------+

Go on by creating the different roles::

    root@auth-node:~# openstack role create admin
    +-------+----------------------------------+
    | Field | Value                            |
    +-------+----------------------------------+
    | id    | f2fd434110344c37a6bfe10fbe1c93ed |
    | name  | admin                            |
    +-------+----------------------------------+
 

These roles are checked by different services. It is not really easy to know which 
service checks for which role, but on a very basic installation you can just live with
``_member_`` (to be used for all the standard users) and ``admin`` 
(to be used for the OpenStack administrators).

Roles are assigned to an user **per-project**. However, if you have the
admin role on just one tenant **you actually are the administrator of
the whole OpenStack installation!**

Assign administrative roles to the admin and _member_ users::

    root@auth-node:~# openstack role add --project admin --user admin admin 

Note that the command does not print any confirmation on successful
completion, so you have to check it using ``openstack role list`` command::


    root@auth-node:~# openstack role list --user admin --project=admin
    +----------------------------------+-------+---------+-------+
    | ID                               | Name  | Project | User  |
    +----------------------------------+-------+---------+-------+
    | f2fd434110344c37a6bfe10fbe1c93ed | admin | admin   | admin |
    +----------------------------------+-------+---------+-------+

Go on with creating a demo user and project::

    root@auth-node:~# openstack project create --domain default --description "Demo Project" demo
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | Demo Project                     |
    | domain_id   | default                          |
    | enabled     | True                             |
    | id          | aab95468ea6e4fd793c03d246164b902 |
    | is_domain   | False                            |
    | name        | demo                             |
    | parent_id   | None                             |
    +-------------+----------------------------------+

    root@auth-node:~# openstack user create --password demo demo
    User Password:
    Repeat User Password:
    +-----------+----------------------------------+
    | Field     | Value                            |
    +-----------+----------------------------------+
    | domain_id | default                          |
    | enabled   | True                             |
    | id        | b9a229ef0492468584ff3b1bd8767f49 |
    | name      | demo                             |
    +-----------+----------------------------------+

    root@auth-node:~# openstack role create _member_
    +-------+----------------------------------+
    | Field | Value                            |
    +-------+----------------------------------+
    | id    | 7a3531b9d2564ad3b446b006ed11a463 |
    | name  | _member_                         |
    +-------+----------------------------------+

    root@auth-node:~# openstack role add --project demo --user demo _member_

Please note that the last command will NOT print any output on successful termination.

Creation of the endpoint
------------------------

Keystone is not only used to store information about users, passwords
and projects, but also to store a catalog of the available services
the OpenStack cloud is offering. To each service is then assigned an
*endpoint* which basically consists of a set of three URLs (`public`,
`internal`, `admin`). Each set of URLs is associated with a specific
region, so that you can use the same keystone instance to give
information about multiple regions.

Of course keystone itself is a service ("identity") so it needs its
own service and endpoint:

The "**identity**" service is created with the following command::

    root@auth-node:~# openstack service create --name keystone --description "OpenStack Identity" identity
    +-------------+----------------------------------+
    | Field       | Value                            |
    +-------------+----------------------------------+
    | description | OpenStack Identity               |
    | enabled     | True                             |
    | id          | 3f0f1773c3bf423da9efedd73fb4cc48 |
    | name        | keystone                         |
    | type        | identity                         |
    +-------------+----------------------------------+

The following command will create an endpoint associated to this
service. About the IP: if you plan to use sshuttle also to connect to
the API of the *inner* cloud, you should use the private IP of the
specific service. If you are using DNAT (or haproxy), you can use the
public IP of the bastion host::

    openstack endpoint create --region RegionOne identity public http://130.60.24.120:5000/v2.0
    +--------------+-----------------------------------+
    | Field        | Value                             |
    +--------------+-----------------------------------+
    | enabled      | True                              |
    | id           | 4e2d0570fd434ddbab7b254c1c3b4524  |
    | interface    | public                            |
    | region       | RegionOne                         |
    | region_id    | RegionOne                         |
    | service_id   | 3f0f1773c3bf423da9efedd73fb4cc48  |
    | service_name | keystone                          |
    | service_type | identity                          |
    | url          | http://130.60.24.120:5000/v2.0    |
    +--------------+-----------------------------------+

    openstack endpoint create --region RegionOne identity internal http://auth-node:5000/v2.0
    +--------------+----------------------------------------+
    | Field        | Value                                  |
    +--------------+----------------------------------------+
    | enabled      | True                                   |
    | id           | dd7fbe5f6e064d5d9e2d6b3ec84c445e       |
    | interface    | internal                               |
    | region       | RegionOne                              |
    | region_id    | RegionOne                              |
    | service_id   | 3f0f1773c3bf423da9efedd73fb4cc48       |
    | service_name | keystone                               |
    | service_type | identity                               |
    | url          | http://auth-node:5000/v2.0             |
    +--------------+----------------------------------------+

    openstack endpoint create --region RegionOne identity admin http://130.60.24.120:35357/v2.0
    +--------------+-----------------------------------------+
    | Field        | Value                                   |
    +--------------+-----------------------------------------+
    | enabled      | True                                    |
    | id           | 0afed953c2fd40b69d7cd6f55e88dd95        |
    | interface    | admin                                   |
    | region       | RegionOne                               |
    | region_id    | RegionOne                               |
    | service_id   | 3f0f1773c3bf423da9efedd73fb4cc48        |
    | service_name | keystone                                |
    | service_type | identity                                |
    | url          | http://130.60.24.120:35357/v2.0         |
    +--------------+-----------------------------------------+

The argument of the ``--region`` option is the region name. For simplicity we will always
use the name ``RegionOne`` since we only have one datacenter...

To get a listing of the available services the command is::

    root@auth-node:~# openstack service list
    +----------------------------------+----------+----------+---------------------------+
    |                id                |   name   |   type   |        description        |
    +----------------------------------+----------+----------+---------------------------+
    | 55d743c4f2a646a1905f30b92276da5a | keystone | identity | Keystone Identity Service |
    +----------------------------------+----------+----------+---------------------------+

while a list of endpoints is shown by the command::

    root@auth-node:~# openstack endpoint list
    +----------------------------------+-----------+--------------+--------------+---------+-----------+---------------------------------+
    | ID                               | Region    | Service Name | Service Type | Enabled | Interface | URL                             |
    +----------------------------------+-----------+--------------+--------------+---------+-----------+---------------------------------+
    | 0afed953c2fd40b69d7cd6f55e88dd95 | RegionOne | keystone     | identity     | True    | admin     | http://130.60.24.120:35357/v2.0 |
    | 4e2d0570fd434ddbab7b254c1c3b4524 | RegionOne | keystone     | identity     | True    | public    | http://130.60.24.120:5000/v2.0  |
    | dd7fbe5f6e064d5d9e2d6b3ec84c445e | RegionOne | keystone     | identity     | True    | internal  | http://auth-node:5000/v2.0      |
    +----------------------------------+-----------+--------------+--------------+---------+-----------+---------------------------------+

Some notes on the type of URLs: 

* *publicurl* is the URL of the client API, and it's used by command
  line clients and external applications.
* *internalurl* is similar to the `publicurl`, but it's meant to be
  used by other OpenStack services, that might not have access to the
  public address of the API, but might be able to access directly the
  internal interface of the API node.
* *adminurl* is used to expose the administrative API. For instance,
  in keystone, creation and deletion of an user is considered an
  `administrative` action and therefore will use this URL.

OpenStack command line tools also allow to change the default endpoint
type. Please refer to the manpage of those commands and look for
`endpoint-type`.

From now on, in order to facilitate the usage of the ``openstack`` it is advisable
to create two files containing the following environment variables::
 
    root@any-host:~# cat admin.sh 
    export OS_PROJECT_DOMAIN_ID=default
    export OS_USER_DOMAIN_ID=default
    export OS_PROJECT_NAME=admin
    export OS_TENANT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=ADMIN_PASS
    export OS_AUTH_URL=http://130.60.24.120:35357/v3
    export OS_IDENTITY_API_VERSION=3

    root@any-host:~# cat demo.sh 
    export OS_PROJECT_DOMAIN_ID=default
    export OS_USER_DOMAIN_ID=default
    export OS_PROJECT_NAME=demo
    export OS_TENANT_NAME=demo
    export OS_USERNAME=demo
    export OS_PASSWORD=DEMO_PASS
    export OS_AUTH_URL=http://130.60.24.120:5000/v3
    export OS_IDENTITY_API_VERSION=3

So that you can load them whenever you need to with::

    root@any-host:~# . ~/admin.sh 
    or 
    root@any-host:~# . ~/demo.sh

Of course, in this case it would be better **not** to put the password
in the file, so that the various openstack commands will prompt for
the password, and you will not risk saving sensible information on disk...

Please keep the connection to the `auth-node` open as we will need to
operate on it briefly.

.. FIXME: update the link
.. Further information about the keystone service can be found at in the
.. `official documentation <http://docs.openstack.org/icehouse/install-guide/install/apt/content/ch_keystone.html>`_


Removing the admin token
------------------------

Once you have a keystone admin user you should *disable* the admin
token. To do that, you have to edit the
``/etc/keystone/keystone-paste.ini``, and remove ``admin_token_auth``
from the ``pipeline`` option in the following configuration sections:

* ``[pipeline:public_api]``
* ``[pipeline:admin_api]``
* ``[pipeline:api_v3]``

The final result should looks like::

    [pipeline:public_api]
    # The last item in this pipeline must be public_service or an equivalent
    # application. It cannot be a filter.
    pipeline = sizelimit url_normalize request_id build_auth_context token_auth json_body ec2_extension user_crud_extension public_service

    [pipeline:admin_api]
    # The last item in this pipeline must be admin_service or an equivalent
    # application. It cannot be a filter.
    pipeline = sizelimit url_normalize request_id build_auth_context token_auth json_body ec2_extension s3_extension crud_extension admin_service

    [pipeline:api_v3]
    # The last item in this pipeline must be service_v3 or an equivalent
    # application. It cannot be a filter.
    pipeline = sizelimit url_normalize request_id build_auth_context token_auth json_body ec2_extension_v3 s3_extension simple_cert_extension revoke_extension federation_extension oauth1_extension endpoint_filter_extension service_v3

As usual, remember to restart the `apache2` service after you update
the configuration file.

If you did it correctly, you should not be able to run `openstack user
list` with only the `OS_TOKEN` and `OS_URL` environment variable, but
should be able to do it setting the variables we saved in the
``admin.sh`` file.
