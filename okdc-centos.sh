#!/bin/sh

VERSION=v1.1
GPG_FILE=RPM-GPG-KEY-k8s
ARCH=$(uname -m)
OS=$(lsb_release -is)
OS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release 2>/dev/null)
MEM=$(cat /proc/meminfo |grep MemTotal|awk '{print $2}')
ADMIN_CONF=/etc/kubernetes/admin.conf
KUBELET_DROPLET=/etc/systemd/system/kubelet.service.d/99-kubelet-droplet.conf
OKDC_BASE=https://raw.githubusercontent.com/kubeup/okdc/master


# User tweakable vars
REPO=${REPO:-https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el$OS_VERSION-$ARCH}
REGISTRY_PREFIX=${REGISTRY_PREFIX:-registry.aliyuncs.com/archon}
DOCKER_MIRROR=${DOCKER_MIRROR:-$(python -c 'import json; d=json.load(open("/etc/docker/daemon.json")); print d.get("registry-mirrors",[])[0]' 2>/dev/null)}
K8S_VERSION=${K8S_VERSION:-v1.6.2}
PAUSE_IMG=${PAUSE_IMG:-$REGISTRY_PREFIX/pause-amd64:3.0}
HYPERKUBE_IMG=${HYPERKUBE_IMG:-$REGISTRY_PREFIX/hyperkube-amd64:$K8S_VERSION}
ETCD_IMG=${ETCD_IMG:-$REGISTRY_PREFIX/etcd:3.0.17}
KUBE_ALIYUN_IMG=${KUBE_ALIYUN_IMG:-registry.aliyuncs.com/kubeup/kube-aliyun}
POD_IP_RANGE=${POD_IP_RANGE:-10.244.0.0/16}
TOKEN=${TOKEN:-$(python -c 'import random,string as s;t=lambda l:"".join(random.choice(s.ascii_lowercase + s.digits) for _ in range(l));print t(6)+"."+t(16)')}

# Only required for node mode
MASTER=${MASTER}

readtty() {
	read "$@" </dev/tty
}

intro() {
cat <<-END
OKDC $VERSION by kubeup
One-liner Kubernetes Deployment in China
http://github.com/kubeup/okdc

END

if [ -z "$MASTER" ]; then
cat <<-END
This will help you provision Kubernetes $K8S_VERSION master on this machine. 

The following mirrors will be used due to inaccessibility of official resources.
$REPO
$HYPERKUBE_IMG
$ETCD_IMG

You will be prompted to input custom docker hub mirror and preferred network layer.

END

else
cat <<-END
This will help you provision Kubernetes $K8S_VERSION node on this machine.

The following mirrors will be used due to inaccessibility of official resources.
$REPO
$HYPERKUBE_IMG

Master: $MASTER
Token: $TOKEN

You will be prompted to input custom docker hub mirror

END
fi
}

pause() {
	readtty -p "Are you sure to continue? (y/N) " INPUT 
	[ "$INPUT" != "y" ] && echo "Abort" && exit 0
}

install_calico_with_etcd() {
	[ -z "$DOCKER_MIRROR" ] && echo "Can't install Calico without a docker mirror. Abort" && exit 3
	if [ $MEM -lt 1500000 ]; then
		readtty -n1 -p "Your memory is not really enough for running k8s master with Calico. This will result in serious performance issues. Are you sure? (y/N) " INPUT
		[ "$INPUT" != "y" ] && echo "Abort" && exit 3
	fi
	wget -O /tmp/calico.yaml http://docs.projectcalico.org/v2.1/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml
	sed -i "s/gcr\.io\/google_containers\/etcd:2\.2\.1/$ETCD_IMG/g" /tmp/calico.yaml
	sed -i "s/quay\.io\///g" /tmp/calico.yaml
	kubectl --kubeconfig=$ADMIN_CONF apply -f /tmp/calico.yaml
}

install_flannel() {
	wget -O /tmp/flannel.yaml https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	sed -i "s/quay\.io\/coreos/${REGISTRY_PREFIX//\//\\/}/g" /tmp/flannel.yaml
	kubectl --kubeconfig=$ADMIN_CONF apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
	kubectl --kubeconfig=$ADMIN_CONF apply -f /tmp/flannel.yaml
}

install_network() {
	while :; do
		echo "Available network layer:"
		echo "1) Flannel"
		echo "2) Calico (mem>1.5G && requires a docker mirror)"
		echo "3) Skip "
		readtty -n1 -p "Choose one to install: " INPUT
		case $INPUT in
			1)
				install_flannel
				;;
			2)
				install_calico_with_etcd
				;;
			3)
				echo -e "\nSkipped."
				;;
			*)
				echo -e "\nHuh??"
				continue
		esac
		break
	done
	echo
}

setup_aliyun() {
#readtty -n 1 -p "Deploy kube-aliyun as well? (to enable SLB, Routes and Volumes support) (Y/n)? " ENABLE_KUBE_ALIYUN
#[ -z $ENABLE_KUBE_ALIYUN ] && ENABLE_KUBE_ALIYUN=y
#
#if [ "$ENABLE_KUBE_ALIYUN" = "y" ]; then
#  [ -n "$ALIYUN_ACCESS_KEY" ] && KEY_DEFAULT="(default: $ALIYUN_ACCESS_KEY)"
#  readtty -p "Aliyun Access Key?$KEY_DEFAULT " INPUT
#  ALIYUN_ACCESS_KEY=${INPUT:-$ALIYUN_ACCESS_KEY}
#  [ -z "$ALIYUN_ACCESS_KEY" ] && echo "Can't proceed without it" && exit 2
#
#  unset KEY_DEFAULT
#  [ -n "$ALIYUN_ACCESS_KEY_SECRET" ] && KEY_DEFAULT="(default: $ALIYUN_ACCESS_KEY_SECRET)"
#  readtty -p "Aliyun Access Key Secret?$KEY_DEFAULT " INPUT
#  ALIYUN_ACCESS_KEY_SECRET=${INPUT:-$ALIYUN_ACCESS_KEY_SECRET}
#  [ -z "$ALIYUN_ACCESS_KEY_SECRET" ] && echo "Can't proceed without it" && exit 2
#fi
	echo
}

update_yum() {
	# Update yum repo
	cat >/etc/pki/rpm-gpg/$GPG_FILE <<-END
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

	cat >/etc/yum.repos.d/k8s.repo <<-END
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

update_kubelet() {
	# Kubelet droplet
	mkdir -p $(dirname $KUBELET_DROPLET)
	cat >$KUBELET_DROPLET <<-END
	[Unit]
	Wants=flexv.service
	After=flexv.service
	[Service]
	Environment="KUBELET_NETWORK_ARGS=--network-plugin=kubenet"
	Environment="KUBELET_EXTRA_ARGS=--pod-infra-container-image=$PAUSE_IMG --cgroup-driver=systemd"
	END
	chmod +x $KUBELET_DROPLET
}

patch_kubelet() {
	# Due to an issue of kubeadm, we need to switch to cni network after kubeadm is done. #43815
	sed -i "/kubenet/d" $KUBELET_DROPLET 
	systemctl daemon-reload
}

restart_kubelet() {
	systemctl restart kubelet
}

set_accelerator() {
	if [ -n "$DOCKER_MIRROR" ]; then
		readtty -p "Docker registry mirror, ex. Aliyun accelerator? (default: $DOCKER_MIRROR) " INPUT
		[ -z "$INPUT" ] && echo "No changes made to registry mirror" && return
		DOCKER_MIRROR=$INPUT
	else
		readtty -p "Docker registry mirror, ex. Aliyun accelerator? (empty to skip) " DOCKER_MIRROR
	fi

# Docker accelerator
	if [ -n "$DOCKER_MIRROR" ]; then
		mkdir -p /etc/docker
		cat >/etc/docker/daemon.json <<-END
		{
		"registry-mirrors": ["$DOCKER_MIRROR"]
		}
		END
	fi
}

run_kubeadm() {
	# Kubeadm config
	cat >/tmp/kubeadm.conf <<-END
	apiVersion: kubeadm.k8s.io/v1alpha1
	kind: MasterConfiguration
	networking:
	  podSubnet: $POD_IP_RANGE
	kubernetesVesion: $K8S_VERSION
	token: $TOKEN
	END

	KUBE_HYPERKUBE_IMAGE=$HYPERKUBE_IMG KUBE_ETCD_IMAGE=$ETCD_IMG KUBE_REPO_PREFIX=$REGISTRY_PREFIX kubeadm init --skip-preflight-checks --config /tmp/kubeadm.conf |tee /tmp/kubeadm.log
	MASTER_IP=$( grep "kubeadm join" /tmp/kubeadm.log|awk '{print $5}' )
}

run_kubeadm_node() {
	KUBE_HYPERKUBE_IMAGE=$HYPERKUBE_IMG KUBE_REPO_PREFIX=$REGISTRY_PREFIX kubeadm join --token $TOKEN $MASTER
}

enable_services() {
# Disable SELinux 
	setenforce 0

# Enable services
	systemctl daemon-reload
	systemctl enable docker && systemctl start docker
	systemctl enable kubelet && systemctl start kubelet
}

show_node_cmd() {
	[ -z "$MASTER_IP" ] && exit 3
  [ -n "$DOCKER_MIRROR" ] && TMP_MIRROR=" DOCKER_MIRROR=$DOCKER_MIRROR"
	echo
	echo Run the following command on your nodes to join the cluster
	echo
	echo "curl -s $OKDC_BASE/okdc-centos.sh|TOKEN=$TOKEN MASTER=$MASTER_IP$TMP_MIRROR sh"
}

check_env() {
	if [ "$OS" != "CentOS" ]; then
		echo "This script only works on CentOS" 1>&2
		exit 1
	fi

	if [ "$(id -u)" != "0" ]; then
		 echo "This script must be run as root" 1>&2
		 exit 1
	fi
}

check_node_prerequisite() {
  [ -z "$MASTER" ] && echo "MASTER is required but not defined" && exit 4
  [ -z "$TOKEN" ] && echo "TOKEN is required but not defined" && exit 4
}

run_master() {
	intro

  check_env
	pause

	update_yum
	set_accelerator
	update_kubelet
	enable_services
	run_kubeadm
	patch_kubelet
  restart_kubelet
	install_network
	
	show_node_cmd
  echo "Done"
}

run_node() {
	intro

  check_env
  check_node_prerequisite
	pause

	update_yum
	set_accelerator
	update_kubelet
  patch_kubelet
	enable_services
	run_kubeadm_node
	
  echo "Done"
}

if [ -n "$MASTER" ]; then
  run_node
else
  run_master
fi


