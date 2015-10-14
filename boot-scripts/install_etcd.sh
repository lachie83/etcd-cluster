#!/bin/bash
set -x
######################################################################
#
# VARIABLES:
#   ETCD_PKG_VERSION = 2.2.0
#
# PORTS:
#     2380, 2379
#######################################################################

## this stack extends the leader elect cluster, so lets source in the cluster profile and expose some variables to us
source /etc/profile.d/cluster

etcd_pkg_version="${ETCD_PKG_VERSION:-2.2.0}"
cluster_name="${ETCD_CLUSTER_NAME}"
dns_zone="${DNS_ZONE}"
etcd_log_file="${ETCD_LOG_FILE:-/var/log/etcd.log}"
echo "installing etcd"

touch "$etcd_log_file"
etcd_dir="/opt/etcd"
(
    cd /tmp
    curl -L  "https://github.com/coreos/etcd/releases/download/v${etcd_pkg_version}/etcd-v${etcd_pkg_version}-linux-amd64.tar.gz" -o "etcd-v${etcd_pkg_version}-linux-amd64.tar.gz"

    tar xzvf "etcd-v${etcd_pkg_version}-linux-amd64.tar.gz"
    mv "etcd-v${etcd_pkg_version}-linux-amd64" "$etcd_dir"
)

cd "$etcd_dir"
name="$(echo $MY_IPADDRESS | perl -pe 's{\.}{}g')"

if [ "true" = "$IS_LEADER" ]; then
    nohup ./etcd -name "$name" -initial-advertise-peer-urls "http://${MY_IPADDRESS}:2380" \
	-listen-peer-urls "http://${MY_IPADDRESS}:2380" \
	-listen-client-urls "http://${MY_IPADDRESS}:2379,http://127.0.0.1:2379" \
	-advertise-client-urls "http://${MY_IPADDRESS}:2379" \
	-initial-cluster-token "$cluster_name" \
	-initial-cluster "$name=http://${MY_IPADDRESS}:2380" 2>&1 >> "$etcd_log_file" &
else
    ## we are not the leaders, lets wait for the leader
    if ./etcdctl --endpoint "http://${cluster_name}.${dns_zone}:2379" cluster-health 2>&1 | grep -q -e "exceeded header timeout" -e "failed to list members" -e "etcd cluster is unavailable or misconfigured"; then 
	echo "waiting for leader";
	sleep 5
    fi

    ## now lets generate a join string
    
    add_member_output="$(./etcdctl --endpoint "http://${cluster_name}.${dns_zone}:2379" member add "$name" "http://${MY_IPADDRESS}:2380")"
    etcd_name="$(echo "$add_member_output" | grep ETCD_NAME | awk -F'\"' '{print $2}')"
    etcd_initial_cluster="$(echo "$add_member_output" | grep ETCD_INITIAL_CLUSTER\\b | awk -F'\"' '{print $2}')"
    etcd_initial_cluster_state="$(echo "$add_member_output" | grep ETCD_INITIAL_CLUSTER_STATE | awk -F'\"' '{print $2}' | perl -pe "s{'}{}g")"
    
    nohup ./etcd -name "$etcd_name" -initial-advertise-peer-urls "http://${MY_IPADDRESS}:2380" \
	-listen-peer-urls "http://${MY_IPADDRESS}:2380,http://127.0.0.1:2380" \
	-listen-client-urls "http://${MY_IPADDRESS}:2379,http://127.0.0.1:2379" \
	-advertise-client-urls "http://${MY_IPADDRESS}:2379" \
	-initial-cluster "${etcd_initial_cluster}" \
	-initial-cluster-state "${etcd_initial_cluster_state}" 2>&1 >> "$etcd_log_file" &
fi
