#!/bin/bash

source /etc/profile.d/cluster

(
    cd /opt/etcd
    member_list_output="$(./etcdctl member list)"
    echo "$member_list_output" | while read id name peer client; do
        member_ip=$(echo "$peer" | awk -F':' '{print $2}' | perl -pe 's{/}{}g')
        if ! echo "$CLUSTER_ADDRESSES,$MY_IPADDRESS" | grep -q "$member_ip"; then
            echo "removing stale member from cluster: $member_ip"
            ## remove the member
        fi
    done
)
