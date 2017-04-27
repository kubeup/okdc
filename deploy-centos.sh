#! /bin/bash

GPG_FILE=RPM-GPG-KEY-k8s
ARCH=`uname -m`
OS=`lsb_release -is`
OS_VERSION=`rpm -q --queryformat '%{VERSION}' centos-release`
MEM=`cat /proc/meminfo |grep MemTotal|awk '{print $2}'`
REPO=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el$OS_VERSION-$ARCH
REGISTRY_PREFIX=registry.aliyuncs.com/archon
PAUSE_IMG=$REGISTRY_PREFIX/pause-amd64:3.0
HYPERKUBE_IMG=$REGISTRY_PREFIX/hyperkube-amd64:v1.6.1
ETCD_IMG=$REGISTRY_PREFIX/etcd:3.0.17
KUBE_ALIYUN_IMG=registry.aliyuncs.com/kubeup/kube-aliyun
K8S_VERSION=v1.6.1
POD_IP_RANGE=10.244.0.0/16
TOKEN=${TOKEN:-`python -c 'import random,string as s;t=lambda l:"".join(random.choice(s.ascii_lowercase + s.digits) for _ in range(l));print t(6)+"."+t(16)'`}
ADMIN_CONF=/etc/kubernetes/admin.conf


function install_calico_with_etcd {
  if [ $MEM -lt 1500000 ]; then
    read -n1 -p "Your memory is not really enough for running k8s master with Calico. This will result in serious performance issues. Are you sure? (y/N) " INPUT
    [ -z "$INPUT" ] && INPUT="n"
    [ "$INPUT" = "n" ] && echo "Abort" && exit 3
  fi
  wget -O /tmp/calico.yaml http://docs.projectcalico.org/v2.1/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml
  sed -i "s/gcr\.io\/google_containers\/etcd:2\.2\.1/$ETCD_IMG/g" /tmp/calico.yaml
  sed -i "s/quay\.io\///g" /tmp/calico.yaml
	kubectl --kubeconfig=$ADMIN_CONF apply -f /tmp/calico.yaml
}

function install_flannel {
  wget -O /tmp/flannel.yaml https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  sed -i "s/quay\.io\/coreos/${REGISTRY_PREFIX//\//\\/}/g" /tmp/flannel.yaml
  kubectl --kubeconfig=$ADMIN_CONF apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
	kubectl --kubeconfig=$ADMIN_CONF apply -f /tmp/flannel.yaml
}

function install_network {
  choices=("calico" "flannel" "skip")
  echo "Choose one to install"
  select INPUT in "${choices[@]}"; do
    case $INPUT in
      flannel)
        install_flannel
        ;;
      calico)
        install_calico_with_etcd
        ;;
      skip)
        echo "Skipped."
        ;;
      *)
        echo "Huh??"
    esac
    break
  done
      
}

function setup_aliyun {
#read -n 1 -p "Deploy kube-aliyun as well? (to enable SLB, Routes and Volumes support) (Y/n)? " ENABLE_KUBE_ALIYUN
#[ -z $ENABLE_KUBE_ALIYUN ] && ENABLE_KUBE_ALIYUN=y
#
#if [ "$ENABLE_KUBE_ALIYUN" = "y" ]; then
#  [ -n "$ALIYUN_ACCESS_KEY" ] && KEY_DEFAULT="(default: $ALIYUN_ACCESS_KEY)"
#  read -p "Aliyun Access Key?$KEY_DEFAULT " INPUT
#  ALIYUN_ACCESS_KEY=${INPUT:-$ALIYUN_ACCESS_KEY}
#  [ -z "$ALIYUN_ACCESS_KEY" ] && echo "Can't proceed without it" && exit 2
#
#  unset KEY_DEFAULT
#  [ -n "$ALIYUN_ACCESS_KEY_SECRET" ] && KEY_DEFAULT="(default: $ALIYUN_ACCESS_KEY_SECRET)"
#  read -p "Aliyun Access Key Secret?$KEY_DEFAULT " INPUT
#  ALIYUN_ACCESS_KEY_SECRET=${INPUT:-$ALIYUN_ACCESS_KEY_SECRET}
#  [ -z "$ALIYUN_ACCESS_KEY_SECRET" ] && echo "Can't proceed without it" && exit 2
#fi
  echo
}

function update_yum {
# Update yum repo
cat >/etc/pki/rpm-gpg/$GPG_FILE <<END
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

mQENBFWKtqgBCADmKQWYQF9YoPxLEQZ5XA6DFVg9ZHG4HIuehsSJETMPQ+W9K5c5
Us5assCZBjG/k5i62SmWb09eHtWsbbEgexURBWJ7IxA8kM3kpTo7bx+LqySDsSC3
/8JRkiyibVV0dDNv/EzRQsGDxmk5Xl8SbQJ/C2ECSUT2ok225f079m2VJsUGHG+5
RpyHHgoMaRNedYP8ksYBPSD6sA3Xqpsh/0cF4sm8QtmsxkBmCCIjBa0B0LybDtdX
XIq5kPJsIrC2zvERIPm1ez/9FyGmZKEFnBGeFC45z5U//pHdB1z03dYKGrKdDpID
17kNbC5wl24k/IeYyTY9IutMXvuNbVSXaVtRABEBAAG0Okdvb2dsZSBDbG91ZCBQ
YWNrYWdlcyBSUE0gU2lnbmluZyBLZXkgPGdjLXRlYW1AZ29vZ2xlLmNvbT6JATgE
EwECACIFAlWKtqgCGy8GCwkIBwMCBhUIAgkKCwQWAgMBAh4BAheAAAoJEPCcOUw+
G6jV+QwH/0wRH+XovIwLGfkg6kYLEvNPvOIYNQWnrT6zZ+XcV47WkJ+i5SR+QpUI
udMSWVf4nkv+XVHruxydafRIeocaXY0E8EuIHGBSB2KR3HxG6JbgUiWlCVRNt4Qd
6udC6Ep7maKEIpO40M8UHRuKrp4iLGIhPm3ELGO6uc8rks8qOBMH4ozU+3PB9a0b
GnPBEsZdOBI1phyftLyyuEvG8PeUYD+uzSx8jp9xbMg66gQRMP9XGzcCkD+b8w1o
7v3J3juKKpgvx5Lqwvwv2ywqn/Wr5d5OBCHEw8KtU/tfxycz/oo6XUIshgEbS/+P
6yKDuYhRp6qxrYXjmAszIT25cftb4d4=
=/PbX
-----END PGP PUBLIC KEY BLOCK-----
END

cat >/etc/yum.repos.d/k8s.repo <<END
[kubernetes]                                                  
name=Kubernetes Repo
baseurl=$REPO
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/$GPG_FILE             
gpgcheck=1
END

# Install stuff
yum updateinfo
yum install -y kubectl kubernetes-cni docker kubelet kubeadm
}

function update_kubelet {
# Kubelet droplet
KUBELET_DROPLET_PATH=/etc/systemd/system/kubelet.service.d
mkdir -p $KUBELET_DROPLET_PATH
cat >$KUBELET_DROPLET_PATH/99-kubelet-droplet.conf <<END
[Unit]
Wants=flexv.service
After=flexv.service
[Service]
Environment="KUBELET_NETWORK_ARGS=--network-plugin=kubenet"
Environment="KUBELET_EXTRA_ARGS=--pod-infra-container-image=$PAUSE_IMG --cgroup-driver=systemd"
END
chmod +x $KUBELET_DROPLET_PATH/99-kubelet-droplet.conf
}

function set_accelerator {
  DOCKER_MIRROR=`python -c 'import json; d=json.load(open("/etc/docker/daemon.json")); print d.get("registry-mirrors",[])[0]'`
  if [ -n "$DOCKER_MIRROR" ]; then
    read -p "Docker registry mirror, ex. Aliyun accelerator? (default: $DOCKER_MIRROR) " INPUT
    [ -z "$INPUT" ] && echo "No changes made to registry mirror" && return
    DOCKER_MIRROR=$INPUT
  else
    read -p "Docker registry mirror, ex. Aliyun accelerator? (empty to skip) " DOCKER_MIRROR
  fi

# Docker accelerator
if [ -n "$DOCKER_MIRROR" ]; then
	mkdir -p /etc/docker
	cat >/etc/docker/daemon.json <<END
{
"registry-mirrors": ["$DOCKER_MIRROR"]
}
END
fi
}

function run_kubeadm {
# Kubeadm config
cat >/tmp/kubeadm.conf <<END
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
networking:
  podSubnet: $POD_IP_RANGE
kubernetesVesion: $K8S_VERSION
token: $TOKEN
END

KUBE_HYPERKUBE_IMAGE=$HYPERKUBE_IMG KUBE_ETCD_IMAGE=$ETCD_IMG KUBE_REPO_PREFIX=$REGISTRY_PREFIX kubeadm init --skip-preflight-checks --config /tmp/kubeadm.conf
}

function enable_services {
# Disable SELinux 
setenforce 0

# Enable services
systemctl daemon-reload
systemctl enable docker && systemctl start docker
systemctl enable kubelet && systemctl start kubelet
}


function main {
if [ "$OS" != "CentOS" ]; then
  echo "This script only works on CentOS" 1>&2
  exit 1
fi

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

update_yum
update_kubelet
set_accelerator
enable_services
run_kubeadm
install_network

}


main

echo "Done"
