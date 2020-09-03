
#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

set -x
hostname | grep pingdirectory1
if [ $? -eq 0 ]; then

    ldapsearch -T -b "dc=ad,dc=authnp,dc=rockfin,dc=com" "&(objectclass=person)" | grep dn: | sed 's/$/\nchangetype:delete\n'/ > tmp.ldif
    ldapmodify -f tmp.ldif

    echo 'dn: cn=Sync User,cn=Root DNs,cn=config
    changetype: add
    ds-privilege-name: audit-data-security
    ds-privilege-name: backend-backup
    ds-privilege-name: backend-restore
    ds-privilege-name: bypass-acl
    ds-privilege-name: config-read
    ds-privilege-name: config-write
    ds-privilege-name: disconnect-client
    ds-privilege-name: ldif-export
    ds-privilege-name: lockdown-mode
    ds-privilege-name: manage-topology
    ds-privilege-name: metrics-read
    ds-privilege-name: modify-acl
    ds-privilege-name: password-reset
    ds-privilege-name: permit-get-password-policy-state-issues
    ds-privilege-name: privilege-change
    ds-privilege-name: server-restart
    ds-privilege-name: server-shutdown
    ds-privilege-name: soft-delete-read
    ds-privilege-name: stream-values
    ds-privilege-name: unindexed-search
    ds-privilege-name: update-schema
    ds-privilege-name: bypass-pw-policy
    ds-privilege-name: bypass-read-acl
    ds-privilege-name: jmx-read
    ds-privilege-name: jmx-write
    ds-privilege-name: jmx-notify
    ds-privilege-name: permit-externally-processed-authentication
    ds-privilege-name: permit-proxied-mschapv2-details
    ds-privilege-name: proxied-auth
    objectClass: top
    objectClass: ds-cfg-root-dn-user
    objectClass: inetOrgPerson
    objectClass: ds-cfg-user
    objectClass: organizationalPerson
    objectClass: person
    sn: User
    cn: Sync User
    ds-cfg-inherit-default-root-privileges: true
    givenName: Sync
    userPassword: 2FederateM0re
    ds-cfg-alternate-bind-dn: cn=Sync User' > tmp.ldif
    ldapmodify -f tmp.ldif   
    
fi
hostname | grep pingdirectory2
if [ $? -eq 0 ]; then

    dsconfig --no-prompt set-backend-prop --backend-name changelog --set changelog-include-attribute:entryUUID
    dsconfig --no-prompt --applyChangeTo single-server set-backend-prop --backend-name changelog --set enabled:true

    echo 'dn: cn=Sync User,cn=Root DNs,cn=config
    changetype: add
    ds-privilege-name: audit-data-security
    ds-privilege-name: backend-backup
    ds-privilege-name: backend-restore
    ds-privilege-name: bypass-acl
    ds-privilege-name: config-read
    ds-privilege-name: config-write
    ds-privilege-name: disconnect-client
    ds-privilege-name: ldif-export
    ds-privilege-name: lockdown-mode
    ds-privilege-name: manage-topology
    ds-privilege-name: metrics-read
    ds-privilege-name: modify-acl
    ds-privilege-name: password-reset
    ds-privilege-name: permit-get-password-policy-state-issues
    ds-privilege-name: privilege-change
    ds-privilege-name: server-restart
    ds-privilege-name: server-shutdown
    ds-privilege-name: soft-delete-read
    ds-privilege-name: stream-values
    ds-privilege-name: unindexed-search
    ds-privilege-name: update-schema
    ds-privilege-name: bypass-pw-policy
    ds-privilege-name: bypass-read-acl
    ds-privilege-name: jmx-read
    ds-privilege-name: jmx-write
    ds-privilege-name: jmx-notify
    ds-privilege-name: permit-externally-processed-authentication
    ds-privilege-name: permit-proxied-mschapv2-details
    ds-privilege-name: proxied-auth
    objectClass: top
    objectClass: ds-cfg-root-dn-user
    objectClass: inetOrgPerson
    objectClass: ds-cfg-user
    objectClass: organizationalPerson
    objectClass: person
    sn: User
    cn: Sync User
    ds-cfg-inherit-default-root-privileges: true
    givenName: Sync
    userPassword: 2FederateM0re
    ds-cfg-alternate-bind-dn: cn=Sync User' > tmp.ldif

    ldapmodify -f tmp.ldif
    
fi