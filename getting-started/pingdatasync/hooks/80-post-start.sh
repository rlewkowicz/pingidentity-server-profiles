#!/usr/bin/env sh
${VERBOSE} && set -x


#
# Set the sync pipe at the beginning of the changelog
#
# realtime-sync set-startpoint \
#     --end-of-changelog \
#     --pipe-name pingdirectory_source-to-pingdirectory_destination

#
# Enable the sync pipe
#
# dsconfig set-sync-pipe-prop \
#     --pipe-name pingdirectory_source-to-pingdirectory_destination  \
#     --set started:true \
#     --no-prompt
    
set -x
dsconfig --no-prompt create-external-server --server-name pingdirectory2:389 --set server-host-name:pingdirectory2 --set server-port:389 --type ping-identity-ds --set "bind-dn:cn=Sync User,cn=Root DNs,cn=config" --set "password:2FederateM0re"
dsconfig --no-prompt create-external-server --server-name pingdirectory1:389 --set server-host-name:pingdirectory1 --set server-port:389 --type ping-identity-ds --set "bind-dn:cn=Sync User,cn=Root DNs,cn=config" --set "password:2FederateM0re"
dsconfig --no-prompt create-sync-source --source-name "Ping Identity Directory Server Source" --type ping-identity --set base-dn:dc=ad,dc=authnp,dc=rockfin,dc=com --set use-changelog-batch-request:true --set server:pingdirectory2:389
dsconfig --no-prompt create-sync-destination --destination-name "Ping Identity Directory Server Destination" --type ping-identity --set base-dn:dc=ad,dc=authnp,dc=rockfin,dc=com --set server:pingdirectory1:389
dsconfig --no-prompt create-sync-pipe --pipe-name Ping_Identity_Directory_Server_Source_to_Ping_Identity_Directory_Server_Destination --set "sync-source:Ping Identity Directory Server Source" --set "sync-destination:Ping Identity Directory Server Destination" --set synchronization-mode:notification
dsconfig --no-prompt create-sync-class --pipe-name Ping_Identity_Directory_Server_Source_to_Ping_Identity_Directory_Server_Destination --class-name DEFAULT --set evaluation-order-index:9999 --set synchronize-creates:true --set synchronize-modifies:true --set synchronize-deletes:true --set auto-mapped-source-attribute:-all-
dsconfig --no-prompt set-sync-class-prop --pipe-name Ping_Identity_Directory_Server_Source_to_Ping_Identity_Directory_Server_Destination --class-name DEFAULT --add auto-mapped-source-attribute:entryUUID
dsconfig --no-prompt set-sync-class-prop --pipe-name Ping_Identity_Directory_Server_Source_to_Ping_Identity_Directory_Server_Destination --class-name DEFAULT --set destination-correlation-attributes:entryUUID
#realtime-sync set-startpoint \
#    --end-of-changelog \
#    --pipe-name Ping_Identity_Directory_Server_Source_to_Ping_Identity_Directory_Server_Destination