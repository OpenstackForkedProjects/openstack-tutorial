---------------
Workshop agenda
---------------

**DRAFT**

Day 1
-----

Morning:

  * Blah-blah cloud blah-as-a-service meet the BOFH
  * Why OpenStack
  * Overview of the services
  * Web Interface
    - import a keypair
    - setup security groups
    - setup the networking
    - create a VM
    - create a volume and attach to the VM
    - create a snapshot
  * LAB: setup a webserver    

Afternoon:

  * real world use cases
    - gc3pie (try it?)
    - elasticluster (try it?)

  * Introduction to the CLI
    - installation, set the environment etc.
    - keypair
    - security group
    - networks and router
    - boot a vm
    - create a volume and attach it
    - attach a second interface to the VM
    - disable port security

  * LAB:
    - create a cluster topology: 1 frontend + n backend
    - frontend with floating IPs, backend connected only to a private,
      not routable network.
    - try to enable NAT on the frontend and use it as gw for the backends


  * intro to the api?
  
Day 2
-----

* more in depth overview of the infrastructure
* MySQL
* rabbitmq
* keystone
* glance

Day 3
-----

* nova
* cinder
* horizon
* neutron

Day 4
-----

* networking
* neutron
* hypervisors
* troubleshooting
* Bonus topic: Python APIs
* Bonus topic: HA
* Bonus topic: swift
