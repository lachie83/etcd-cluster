#!/bin/bash
######################################################################
#
# VARIABLES:
#   ETCD_VERSION = 2.2.0
#
# PORTS:
#     2380, 2379
#######################################################################

## this stack extends the leader elect cluster, so lets source in the cluster profile and expose some variables to us
source /etc/profile.d/cluster

echo "installing etcd"

etcd_dir="/opt/etcd"
(
    cd /tmp
    curl -L  "https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"

    tar xzvf "etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
    mv "etcd-v${ETCD_VERSION}-linux-amd64" "$etcd_dir"
)

cd "$etcd_dir"
name="$(echo $MY_IPADDRESS | perl -pe 's{\.}{}g')"

if [ "true" = "$IS_LEADER" ]; then
    ./etcd -name "$name" -initial-advertise-peer-urls "http://${MY_IPADDRESS}:2380" \
	-listen-peer-urls "http://${MY_IPADDRESS}:2380" \
	-listen-client-urls "http://${MY_IPADDRESS}:2379,http://127.0.0.1:2379" \
	-advertise-client-urls "http://${MY_IPADDRESS}:2379" \
	-initial-cluster-token "$CLUSTER_NAME"
else
    ## we are not the leaders, lets generate a join string
    add_member_output="$(etcdctl --endpoint "http://${CLUSTER_NAME}.${DNS_ZONE}:2379" member add "$name" "http://${MY_IPADDRESS}:2380")"
    etcd_name="$(echo $add_member_output | grep ETCD_NAME | awk -F'\"' '{print $2}')"
    etcd_initial_cluster="$(echo $add_member_output | grep ETCD_INITIAL_CLUSTER | awk -F'\"' '{print $2}')"
    etcd_initial_cluster_state="$(echo $add_member_output | grep ETCD_INITIAL_CLUSTER_STATE | awk -F'\"' '{print $2}')"
    
    
    ./etcd -name "$etcd_name" -initial-advertise-peer-urls "http://${MY_IPADDRESS}:2380" \
	-listen-peer-urls "http://${MY_IPADDRESS}:2380" \
	-listen-client-urls "http://${MY_IPADDRESS}:2379" \
	-advertise-client-urls "http://${MY_IPADDRESS}:2379" \
	-initial-cluster "${etcd_initial_cluster}" \
	-initial-cluster-state "${etcd_initial_cluster_state}"
fi
