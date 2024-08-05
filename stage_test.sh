#!/bin/bash

CRONJOBS=$(oc get cronjobs -l "service=floorist" | awk 'NR>1 {print $1}')

if [[ -z "$CRONJOBS" ]]; then
    echo "ERROR: no cronjobs found"
    exit 1
fi

for CRONJOB in $CRONJOBS; do
    SUCCESS=$(oc get job -l "pod=${CRONJOB}" -o jsonpath='{.items[].status.succeeded}{"\n"}')

    if [[ -z "$SUCCESS" ]]; then
        echo "ERROR: cronjob $CRONJOB has not created any jobs"
        exit 1
    fi

    if [[ "$SUCCESS" != "1" ]]; then
        echo "ERROR: cronjob $CRONJOB has not created successful jobs"
        exit 1
    fi
done
