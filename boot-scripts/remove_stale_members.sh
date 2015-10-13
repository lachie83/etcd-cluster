#!/bin/bash

cp ../extends/boot-scripts/lib/group_addresses.py /usr/bin/

script="/usr/bin/remove_unhealthy.sh"

cat <<"EOF" > "$script"
#!/bin/bash

source /etc/profile.d/cluster

addresses="$(python /usr/bin/group_addresses.py)"

## if we aren't in the address list it was a bad request

if ! echo "$addresses" | grep -q "$MY_IPADDRESS"; then
    exit 0
fi
(
    cd /opt/etcd
    cluster_health_output="$(./etcdctl cluster-health | grep "member")"
    echo "$cluster_health_output"
    echo
    echo "$cluster_health_output" | while read member member_id therest; do
        health=$(echo "$therest" | awk -F':' '{print $2}' | perl -pe 's{/}{}g')
        member_ip=$(echo "$therest" | awk -F':' '{print $3}' | perl -pe 's{/}{}g')
        ### first, lets remove any unhealthy members

        echo "checking id:$member_id on ip:$member_ip which is $health"
        if (echo "$health" | grep -q unhealthy) || (! echo "$addresses" | grep -q "$member_ip"); then
            echo "removing stale member from cluster: $member_ip"
            ./etcdctl member remove "$member_id"
        fi
    done
)


EOF

chmod +x "$script"

echo "* * * * * $script >> /var/log/remove_unhealthy.log" | crontab
