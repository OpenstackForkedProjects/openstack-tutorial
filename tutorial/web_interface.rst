-----------------------
OpenStack web interface
-----------------------

The goal of this interactive session is to get accustomed to the web
interface of OpenStack (called: Horizon)

What we will do:

* login on http://cscs2015.s3it.uzh.ch
* import a keypair
* look around :)
* crete the basic networking
* start a VM
* associate a Floating IP
* check security groups
* create a volume and attach it to the VM
* detach the volume
* create a snapshot
* start a new VM from snapshot

Finally, a lab exercise.

Random information useful to recap
++++++++++++++++++++++++++++++++++

Logging in: users and projects
------------------------------

Projects (aka tenants) are group of *trusted* users. Most of the
resources are owned by the project, and not the user itself. This
means that any user can delete any volume/instance/image owned by the
tenant.

The only resource owned by the user only is the keypair.

An user belongs to a tenant if he/she has a *role* in the tenant. By
default only two roles are defined in OpenStack:

* Member (regular user)
* admin (admin *of the whole cloud*)

A cloud administrator can create additional roles and change the
permissions associated to a specific role.

Import a keypair
----------------

A keypair contains an ssh public key. When a VM started, if a specific
contextualization software is installed (like `cloud-init
<https://cloudinit.readthedocs.org/en/latest/>`_) the ssh public key
corresponding to the keypair used to start the VM is downloaded on the
VM and injected in the user's ssh authorization key.

Basic networking
----------------

There are multiple options for networking with OpenStack, and we will
see a few of them during this tutorial.

Today, however, we will only create a basic network setup: a private
network attached to the `public` external network already present.

1) create a private network
2) create a router
3) set gateway
4) add router interface to the private network

With this setup you will not be able to directly access the VM. To do
that, you will have to create a floating IP from the public network
and attach it to the VM.

Start a VM
----------

Start a new VM. Ensure you chose:

* the right flavor for the image
* the right keypair
* the correct network interface

Optionally, add something to the `userdata`

Volumes
-------

Volumes are usually *persistent*, which means that they are not
deleted when you terminate your instance.

A volume can usually be attached to a single VM at the time: think of
an USB stick, you can plug it or unplug it to one computer at the
time.

A volume when created is empty: it has to be partitioned and/or
formatted when attached to the VM.

Data on a volume can only be accessed from within the cloud.

You can snapshot a volume, and create a new volume from it.

You can backup a volume to a different storage backend. Note, however,
that it's a backup of the *whole raw data* (regardless of the actual
used space, as cinder has no access to the content)

Snapshots
---------

A snapshot is a way to create a new glance image from the disk of a
running instance. It's often used to customize an instance on the
cloud and then start multiple instances from it.

.. _lab-exercise-1:

Lab exercise 1
++++++++++++++

In this lab exercise you are requested to:

**Create a working web server without connecting to the VM**

One or more of the following hints could be helpful (or misleading):

* the "post installation script" is executed when the VM is booted as
  root
* snapshots are used to create customized images
* floating IPs are used to configure a 1:1 NAT, allowing you to access
  the VM from internet.
* security groups are defined so that any incoming traffec is blocked
  unless explicitly allowed
* If you need persistent data you usually create a volume
