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
    member_list_output="$(./etcdctl member list)"
    echo "$member_list_output"
    echo
    echo "$member_list_output" | while read id name peer client; do
        member_ip=$(echo "$peer" | awk -F':' '{print $2}' | perl -pe 's{/}{}g')
        if ! echo "$addresses" | grep -q "$member_ip"; then
            echo "removing stale member from cluster: $member_ip"
                member_id="$(echo "$member_list_output" | grep "$member_ip" | awk -F':' '{print $1}')"
                    ./etcdctl member remove "$member_id"
        fi
    done
)

EOF

chmod +x "$script"

echo "* * * * * $script > /var/log/remove_unhealthy.log" | crontab
