# my-ctr-dns

## Background

'my container dns':  simple demo using containerd showing use of bind9 DNS with your local lan environment.

```
N.B. I am long-term docker user recently switched to containerd before I did this example. <code>nerdctl compose</code> allows you to use all your old docker files pretty much unmodified, that team did a great job.
```

Suppose you want to run bind as a local name resolver, and you want to isolate it in a container and not add it to your machine config.

```
N.B. bind9 has a lot of config that has to be done correctly else its presence is painful, so there are a lot of 'lightweight' alternatives. Unfortunately, many lightweight alternatives support limited use-cases, and simply running a legit bind9 instance in a container is the best option.
``` 

## Setup

This provided as an example only, you are going to have to experiment with your env.

Refer to the attached bind-docker-compose.yml. This supposes you want to run name resolution for a domain called 'huachuca.lan', and you have a directory subtree with the config you want to use.

Specifically note:
```
    volumes:
      - /work/ptschneider/github/my-ctr-dns/huachuca.lan/conf:/etc/bind
      - /work/ptschneider/github/my-ctr-dns/huachuca.lan/work:/var/cache/bind
      - /work/ptschneider/github/my-ctr-dns/huachuca.lan/zone:/var/lib/bind
      - /work/ptschneider/github/my-ctr-dns/huachuca.lan/log:/var/log

```
The first part is the local directory, the second part is the mount point inside the container. Change the first part to match your config; don't change the second part unless you are sure. The directories for the first part are ones you have to create.

An example below shows a directory subtree for a hypothetical zone 'huachuca.lan'.

```
$ tree huachuca.lan
huachuca.lan
├── conf
│   ├── db.huachuca.lan
│   ├── named.conf
│   ├── named.conf.local
│   └── named.conf.options
├── log
├── work
└── zone
```

You have to create the files under 'conf'. An example below for named.conf:

```
;
;
$TTL	1d
@	IN	SOA	dns.huachuca.lan. root.huachuca.lan. (
		        2024120300		; Serial
				1d		; Refresh
				1h		; Retry
				1w		; Expire
				1h )	; Negative Cache TTL
;
 	IN	NS	dns.huachuca.lan.
 	IN	MX 10	mail.huachuca.lan.
;
dns.huachuca.lan.			IN	A	172.27.10.250
mail.huachuca.lan.		IN	A	172.27.10.251
ableant.huachuca.lan.		IN	A	172.27.10.252
brightbison.huachuca.lan.		IN	A	172.27.10.253
registry.huachuca.lan.		IN	A	172.27.10.254
www.huachuca.lan.			IN	CNAME	ableant.huachuca.lan.
mongo.huachuca.lan.		IN	CNAME	brightbison.huachuca.lan.

```

Suppose you are going to run qty-2 instances (e.g. VMs or containers) named ableant and brightbison and you want their names to resolve for your new domain as they will run mail, web or db services. Assign A records for the addresses you intend to use and CNAME records for the aliases.

Then, you need to specify named.conf.options which defines the options for the running bind daemon; an example:

```
acl internals {
        127.0.0.1;
	10.5.1.0/24;
	172.16.0.0/16;
	172.17.0.0/16;
	172.18.0.0/16;
	172.19.0.0/16;
	172.20.0.0/16;
	172.27.0.0/16;
	172.28.0.0/16;
	172.29.0.0/16;
	172.30.0.0/16;
	172.31.0.0/16;
};

options {
	directory "/var/cache/bind";

	 forwarders {
	 	10.5.1.3;
	 	10.5.1.23;
	//	208.67.222.222; # dns.sse.cisco.com
	//	208.67.220.220; # dns.sse.cisco.com
	 };

	//========================================================================
	// If BIND logs error messages about the root key being expired,
	// you will need to update your keys.  See https://www.isc.org/bind-keys
	//========================================================================
	dnssec-validation auto;

        // qname-minimization off;

	// listen-on-v6 { any; };
	listen-on-v6 { none; };

	// allow-query { internals; externals; };
	allow-query { internals; };

	allow-transfer { localhost; };

	allow-recursion { internals; };

	auth-nxdomain no;    # conform to RFC1035
};

```
Here, we only accept inquiries from our 'internals' local 172.x subnet and we use our regular internal DNS as forwarders for anything we're not defining locally here. We could define a list of external subnets to allow but none are defined in this example. 

## Running

First, I assume you are running Linux and have containerd and nerdctl installed on your machine. 

Next, create a containerd network with a name that matches the domain you want to use:

```
sudo nerdctl network create --driver=bridge --ipam-driver=default --subnet 172.27.10.248/29 huachuca.lan
```

Then, we can start our bind container:

```
sudo nerdctl compose -f bind-compose.yml up -d
```
You should see it showing a good running status with:
```
sudo nerdctl container ls
or
sudo nerdctl ps -a
```

In this example, the container running bind should have received the address 172.27.10.250, and you should be able to run 'nslookup dns.huachuca.lan 172.27.10.250' and see it resolve successfully. You should also be able to resolve any of the names in the huachuca.lan/conf/db.huachuca.lan file.

Was not able to see a physical logfile in the container volume; seems to only output to stdout, which is being properly captured. ('nerdctl ... logs')

### Miscellany

If you need to get 'inside' your dns container:

```
sudo nerdctl exec -ti dns /bin/sh
```

When it is time to shutdown, and you remember which compose you used to launch it, just run:

```
sudo nerdctl compose -f bind-docker-compose.yml down  --remove-orphans
```

Unfortunately, AFAICT there's no reliable way to determine which YAML file was used to startup (inspecting the container can reveal clues, but nothing is certain); you have to remember which, or re-author something compatible.


There's also an example for starting an image registry on that subnet (common for central-deployment configs):

```
sudo nerdctl compose -f registry-compose.yml up -d
```
For this to work, you need to allow it in your containerd config.

/etc/containerd/certs.d contains entries for each host you allow images to be pulled from. If you wanted to allow the localhost serve images on port 5001, you would create a subdirectory called '127.0.0.1:5001' and have a file witin called hosts.toml that looks like:
```
server = "http://localhost:5001"

[host."http://localhost:5001"]
  capabilities = ["pull","push","resolve"]
  skip_verify = true

```

skip_verify controls whether or not it is a TLS connection




