# One-liner Kubernetes Deployment in China aka OKDC

Deploy fully functional Kubernetes in China with a one-liner

## Why 

Automate the process, save some time, and stab GFW in the ass.

## What's Included

Kubernetes, Etcd, Network layer (flannel, calico), GFW related workarounds.

## Usage

Run on master:

`curl -s https://raw.githubusercontent.com/kubeup/okdc/master/okdc-centos.sh|sh`

Command for nodes will show up after master is done.

## Supported OS

- CentOS x86_64 6/7

## Supported Kubernetes Version

- v1.6.2
- v1.7.0

## Caveats

You need a docker registry mirror address to install Calico (try Aliyun Accelerator). 
If you don't have that, use flannel instead.
