#!/bin/bash

CRONJOBS=$(oc get cronjobs -l "service=floorist" --all-namespaces | awk 'NR>1 {print $1}')

if [[ -z "$CRONJOBS" ]]; then
    echo "ERROR: no cronjobs found"
    exit 1
fi

for CRONJOB in $CRONJOBS; do
    NAMESPACE=$(oc get cronjob $CRONJOB -o jsonpath='{.metadata.namespace}' --all-namespaces)

    SUCCESS=$(oc get job -l "pod=${CRONJOB}" -o jsonpath='{.items[].status.succeeded}{"\n"}' -n $NAMESPACE)

    if [[ -z "$SUCCESS" ]]; then
        echo "ERROR: cronjob $CRONJOB has not created any jobs in namespace $NAMESPACE"
        exit 1
    fi

    if [[ "$SUCCESS" != "1" ]]; then
        echo "ERROR: cronjob $CRONJOB has not created successful jobs in namespace $NAMESPACE"
        exit 1
    fi
done
