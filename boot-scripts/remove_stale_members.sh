#!/bin/bash

source /etc/profile.d/cluster

(
    cd /opt/etcd
    member_list_output="$(./etcdctl cluster-health | grep -e unhealthy -e unreachable)"
    echo "$member_list_output" | while read word id is status ip therest; do
        ./etcdctl member remove "$id"
    done
)
