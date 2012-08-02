WaspswithRainofStings
====================

By Ji-Hun Seol (jihoon.seol@gmail.com)

Description
-----------

WaspswithRainofStings is a distributed heavy load generator in Ruby inspired by waspswithmachineguns(https://github.com/newsapps/waspswithmachineguns).

This is a utility of arming(create and install load program) many wasps (micro EC2 instances)
from multiple regions(EC2 zones) to attack (load test) targets(web applications).

Installation
------------

	$ git clone https://github.com/jhseol/waspswithrainofstings.git
	$ cd waspswithrainofstings
	$ bundle install

Configuring EC2 credentials
---------------------------
	
Wasps uses aws-sdk gem to communicate with EC2 and supports all the same methods of storing credentials that it does.
Set access key and secret key for config/aws.yml to access your EC2 account.

	access_key_id: xxxxxxxxxxxxxxxxx
	secret_access_key: xxxxxxxxxxxxxxxxx

Running
-------

	Usage:
	
	To set credentials:
	  $ wasp set [AWS Credential file]
	
	To launch 6 wasps:
	  - launch 6 instances in us-east zone with private key named wasps
	  $ wasp up -k wasps -s 6 
	
	  - launch 5 instances in us-west-2 zone with ami-8cb33ebc AMI, username ubuntu and private key named wasps
	  $ wasp up -k wasps -z us-west-2 -a ami-8cb33ebc -s 5 -l ubuntu
	
	To check status:
	  $	wasp status
	
	To equip weapon(default: apachebench):
	  $ wasp equip

	To attack target with 1000 requests and 100 concurrent users per each wasp:
	  $ wasp attack -n 1000 -c 100 -u http://target_site

    To attack target with incrementally increase wasps from 1 to 10000 during 60 seconds:
	  $ wasp rattack -p 10000:60 -u http://target_site
	
	To sleep wasps:
	  $ wasp down
	
	To see options:
	  $ wasp help
	
*Note*: the default EC2 security group is called 'wasps' and by default it locks out SSH access.

*Note*: if you didn't specify a zone for EC2 instances, it use default zone 'us-east'.

*Please remember to do this*--we aren't responsible for your EC2 bills.

Notice! (PLEASE READ)
---------------------
If you decide to use the Wasps, please keep in mind the following important notice: they are, more-or-less a distributed denial-of-service attack in a fancy package and, therefore, if you point them at any server you don’t own you will behaving *unethically*, have your Amazon Web Services account *locked-out*, and be *liable* in a court of law for any downtime you cause.

You have waspn warned.

License
-------
MIT.
