#!/usr/bin/env sh
#
# Ping Identity DevOps - Docker Build Hooks
#
#- This hook runs through the followig phases:
#-
${VERBOSE} && set -x

# shellcheck source=../../../../pingcommon/opt/staging/hooks/pingcommon.lib.sh
. "${HOOKS_DIR}/pingcommon.lib.sh"

# shellcheck source=pingdirectory.lib.sh
test -f "${HOOKS_DIR}/pingdirectory.lib.sh" && . "${HOOKS_DIR}/pingdirectory.lib.sh"

#
#- * Ensures the PingDirectory service has been started an accepts queries.
#
echo "Waiting until PingDirectory service is running on this Server (${_podInstanceName:?})"
echo "        ${_podHostname:?}:${_podLdapsPort:?}"
waitUntilLdapUp "${_podHostname}" "${_podLdapsPort}" ""

#
#- * Updates the Server Instance hostname/ldaps-port
#
echo "Updating the Server Instance hostname/ldaps-port:
         instance: ${_podInstanceName}
         hostname: ${_podHostname}
       ldaps-port: ${_podLdapsPort}"

# shellcheck disable=SC2086
dsconfig set-server-instance-prop --no-prompt --quiet \
    --instance-name "${_podInstanceName}" \
    --set hostname:${_podHostname} \
    --set ldaps-port:${_podLdapsPort}
    
set -x
cat << EOF > tmp.ldif
dn: cn=Sync User,cn=Root DNs,cn=config
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
ds-cfg-alternate-bind-dn: cn=Sync User
EOF
ldapmodify -f tmp.ldif
hostname | grep pingdirectory1
if [ $? -eq 0 ]; then
    ldapsearch -T -b "dc=ad,dc=authnp,dc=rockfin,dc=com" "&(objectclass=person)" | grep dn: | sed 's/$/\nchangetype:delete\n'/ > tmp.ldif
    ldapmodify -f tmp.ldif
fi
hostname | grep pingdirectory2
if [ $? -eq 0 ]; then
    dsconfig --no-prompt set-backend-prop --backend-name changelog --set changelog-include-attribute:entryUUID
    dsconfig --no-prompt --applyChangeTo single-server set-backend-prop --backend-name changelog --set enabled:true
fi

_updateServerInstanceResult=$?
echo "Updating the Server Instance ${_podInstanceName} result=${_updateServerInstanceResult}"







#
#- * Check to see if PD_STATE is GENISIS.  If so, no replication will be performed
#
if test "${PD_STATE}" = "GENESIS" ; then
    echo "PD_STATE is GENESIS ==> Replication on this server won't be setup until more instances are added"
    exit 0
fi

#
#- * Ensure the Seed Server is accepting queries
#
echo "Running ldapsearch test on SEED Server (${_seedInstanceName:?})"
echo "        ${_seedHostname:?}:${_seedLdapsPort:?}"
waitUntilLdapUp "${_seedHostname}" "${_seedLdapsPort}" ""

#
#- * Check the topology prior to enabling replication
#
_priorTopoFile="/tmp/priorTopology.json"
rm -rf "${_priorTopoFile}"
manage-topology export \
    --hostname "${_seedHostname}" \
    --port "${_seedLdapsPort}" \
    --exportFilePath "${_priorTopoFile}"
_priorNumInstances=$(jq ".serverInstances | length" "${_priorTopoFile}" )

#
#- * If this server is already in prior topology, then replication is already enable
#
if test ! -z "$(jq -r ".serverInstances[] | select(.instanceName==\"${_podInstanceName}\") | .instanceName" "${_priorTopoFile}")"; then
    echo "This instance (${_podInstanceName}) is already found in topology --> No need to enable replication"
    dsreplication status --displayServerTable --showAll
    exit 0
fi

#
#- * If the server being setup is the Seed Instance, then no replication will be performed
#
if test "${_podInstanceName}" = "${_seedInstanceName}"; then
    echo ""
    echo "We are the SEED Server: ${_seedInstanceName} --> No need to enable replication"
    echo "TODO: We need to check for other servers"
    exit 0
fi

#
#- * Get the current Toplogy Master
#
_masterTopologyInstance=$(ldapsearch --hostname "${_seedHostname}" --port "${_seedLdapsPort}" --terse --outputFormat json -b "cn=Mirrored subtree manager for base DN cn_Topology_cn_config,cn=monitor" -s base objectclass=* master-instance-name | jq -r .attributes[].values[])
_masterTopologyHostname="${_seedHostname}"
_masterTopologyLdapsPort="${_seedLdapsPort}"
_masterTopologyReplicationPort="${_seedReplicationPort:?}"


#
#- * Determine the Master Toplogy server to use to enable with
#
if test "${_priorNumInstances}" -eq 1; then
    echo "Only 1 instance (${_masterTopologyInstance}) found in current topology.  Adding 1st replica"
else
    if test "${_masterTopologyInstance}" = "${_seedInstanceName}"; then
        echo "Seed Instance is the Topology Master Instance"
        _masterTopologyHostname="${_seedHostname}"
        _masterTopologyLdapsPort="${_seedLdapsPort}"
        _masterTopologyReplicationPort="${_seedReplicationPort}"
    else
        echo "Topology master instance (${_masterTopologyInstance}) isn't seed instance (${_seedInstanceName})"

        _masterTopologyHostname=$(jq -r ".serverInstances[] | select(.instanceName==\"${_masterTopologyInstance}\") | .hostname" "${_priorTopoFile}")
        _masterTopologyLdapsPort=$(jq ".serverInstances[] | select(.instanceName==\"${_masterTopologyInstance}\") | .ldapsPort" "${_priorTopoFile}")
        _masterTopologyReplicationPort=$(jq ".serverInstances[] | select(.instanceName==\"${_masterTopologyInstance}\") | .replicationPort" "${_priorTopoFile}")
    fi
fi


#
#- * Enabling Replication
#
printf "
#############################################
# Enabling Replication
#
# Current Master Topology Instance: ${_masterTopologyInstance}
#
#   %60s        %-60s
#   %60s  <-->  %-60s
#############################################
" "Topology Master Server" "POD Server" "${_masterTopologyHostname}:${_masterTopologyReplicationPort}" "${_podHostname}:${_podReplicationPort:?}"

dsreplication enable \
      --retryTimeoutSeconds ${RETRY_TIMEOUT_SECONDS} \
      --trustAll \
      --host1 "${_masterTopologyHostname}" \
      --port1 "${_masterTopologyLdapsPort}" \
      --useSSL1 \
      --replicationPort1 "${_masterTopologyReplicationPort}" \
      --bindDN1 "${ROOT_USER_DN}" \
      --bindPasswordFile1 "${ROOT_USER_PASSWORD_FILE}" \
      \
      --host2 "${_podHostname}" \
      --port2 ${_podLdapsPort} \
      --useSSL2 \
      --replicationPort2 "${_podReplicationPort}" \
      --bindDN2 "${ROOT_USER_DN}" \
      --bindPasswordFile2 "${ROOT_USER_PASSWORD_FILE}" \
      \
      --adminUID "${ADMIN_USER_NAME}" \
      --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
      --no-prompt --ignoreWarnings \
      --baseDN "${USER_BASE_DN}" \
      --noSchemaReplication \
      --enableDebug --globalDebugLevel verbose

_replEnableResult=$?
echo "Replication enable for POD Server result=${_replEnableResult}"

if test ${_replEnableResult} -ne 0; then
    echo "Not running dsreplication initialize since enable failed with a non-successful return code"
    exit ${_replEnableResult}
fi

#
#- * Get the new current topology
#
echo "Getting Topology from SEED Server"
rm -rf "${TOPOLOGY_FILE}"
manage-topology export \
    --hostname "${_seedHostname}" \
    --port "${_seedLdapsPort}" \
    --exportFilePath "${TOPOLOGY_FILE}"

cat "${TOPOLOGY_FILE}"

#
#- * Initialize replication
#
echo "Initializing replication on POD Server"
dsreplication initialize \
      --retryTimeoutSeconds "${RETRY_TIMEOUT_SECONDS}" \
      --trustAll \
      \
      --topologyFilePath "${TOPOLOGY_FILE}" \
      \
      --hostDestination "${_podHostname}" --portDestination "${_podLdapsPort}" --useSSLDestination \
      \
      --baseDN "${USER_BASE_DN}" \
      --adminUID "${ADMIN_USER_NAME}" \
      --adminPasswordFile "${ADMIN_USER_PASSWORD_FILE}" \
      --no-prompt \
      --enableDebug \
      --globalDebugLevel verbose

_replInitResult=$?
echo "Replication initialize result=${_replInitResult}"

test ${_replInitResult} -eq 0 && dsreplication status --displayServerTable --showAll

exit ${_replInitResult}
