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

This will create a directory `cscs2-15` where everything will be
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
activation script)

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

To install a package just run `pip install <package-name>` with the
virtualenv already loaded::

    (cscs2015)antonio@kenny:~$ pip install python-{openstack,nova,glance,cinder,neutron}client
    [...]
    (cscs2015)antonio@kenny:~$

.. _lab-exercise-2:

Brief list of commands we will use
----------------------------------


A few things the web interface does not allow you to do
+++++++++++++++++++++++++++++++++++++++++++++++++++++++


Attaching network interfaces live
---------------------------------

Using Neutron you can attach and detach a network interface at
runtime, using the following commands:

* ``nova interface-list <server>`` to list interfaces attached to a VM
* ``nova interface-attach ...`` to attach an interface
* ``nova interface-detach ...`` to detach an interface

Remove any protection from a port
---------------------------------

By default Neutron configures complex firewall rules for each port of
each VM for security reasons. This will prevent you, among other
things, from using an IP different from the one Neutron associated to
the VM.

There are legitimate cases, however, where you need to associate more
than one IP to the same interface, but this is not possible with
Neutron.

However (assuming the cloud is configured accordingly), you can
disable these protections on a single port, simply running::

    neutron port-update --port-security-enabled=False --no-security-groups <port-id>



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
