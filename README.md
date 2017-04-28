# One-liner Kubernetes Deployer in China

Deploy fully functional Kubernetes in China with a one-liner

## Why 

Automate the process, save some time, and stab GFW in the ass.

## Usage

Run on master:

`curl -s https://raw.githubusercontent.com/ledzep2/k8s-deploy-cn/master/deploy-centos.sh|sh`

Command for nodes will show up after master is done.

## Supported OS

- CentOS x86_64 6/7

## Supported Kubernetes Version

- v1.6.1

## Caveats

You need a docker registry mirror address to install Calico. If you don't have that, 
use flannel instead.
