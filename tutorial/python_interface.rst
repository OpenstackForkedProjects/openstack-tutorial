.. #!/usr/bin/env  python

------------------------------------------
Intro to the python interface of OpenStack
------------------------------------------

As SysAdmin, we often need to create scripts to interact with our
infrastructure. Luckly, OpenStack is *meant* to be scriptable. It
supports RESTful APIs, and there are bindings for basically any
programming language. In this very short session we will only see one
simple example in Python.

First of all, import the openstack modules::

 import os
 from keystoneclient import session
 from keystoneclient.auth.identity import v3 as identity
 from novaclient import client as nova_client
 from glanceclient import client as glance_client
 from cinderclient import client as cinder_client

If you also configure logging, you will be able to see the errors of
the python openstack libraries::

 import logging
 log = logging.getLogger()
 log.addHandler(logging.StreamHandler())
 log.setLevel(logging.INFO)

Create a function to create a keystone session::

 def make_session(opts):
     """Create a Keystone session"""
     auth = identity.Password(
         auth_url=opts.os_auth_url,
         username=opts.os_username,
         password=opts.os_password,
         project_name=opts.os_project_name,
         user_domain_id=getattr(opts, 'os_user_domain_id', 'default'),
         project_domain_id=getattr(opts, 'os_user_domain_id', 'default'))
     sess = session.Session(auth=auth)
     return sess

In a production script you would use `argparse` to setup the proper
options, but in our case we can just cheat::

 class X(object): pass
 opts = X()
 for name in ['os_auth_url', 'os_username', 'os_password', 'os_project_name']:
   setattr(opts, name, os.getenv(name.upper()))

Now you can create a nova client::

 nclient = nova_client.Client('2', session=sess)
 gclient = glance_client.Client('2', session=sess)
 client = cinder_client.Client('2', session=sess)
 nnclient = neutron_client.Client(session=sess)

Look at the flavors::

 flavors = nclient.flavors.list()

Look at the images::

 images = list(gclient.images.list())

Look at the networks::

 networks = nclient.networks.list()

Start a server::

 vm = nclient.servers.create(
    'test-vm', flavors[0], images[0],
    key_name='antonio',
    nics=[{'net-id': networks[0]}])
