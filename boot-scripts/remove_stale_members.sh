#!/bin/bash

source /etc/profile.d/cluster

member_list_output="$()"
for member_ip in "$member_list_output"; do
    if ! echo "$CLUSTER_ADDRESSES" | grep -q "$member_ip"; then
	echo "removing stale member from cluster: $member_ip"
	## remove the member
    fi
done
