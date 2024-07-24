#!/bin/bash

# New Floorist image used by the operator
NEW_FLOORIST_IMG="$(
    oc get deployment.apps -o jsonpath='{.items[?(.metadata.name=="floorist-operator-controller-manager")].spec.template.spec.containers[?(.name=="manager")].env[?(.name=="FLOORIST_IMAGE")].value}{"\n"}'
):$(
    oc get deployment.apps -o jsonpath='{.items[?(.metadata.name=="floorist-operator-controller-manager")].spec.template.spec.containers[?(.name=="manager")].env[?(.name=="FLOORIST_IMAGE_TAG")].value}{"\n"}'
)"

CRONJOBS=$(oc get cronjobs | awk 'NR>1 {print $1}')

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

    # Comparing operator's image with the image used by the (cron)jobs
    if [[ "$NEW_FLOORIST_IMG" != "$(oc get job -l "pod=${CRONJOB}" -o jsonpath='{.items[].spec.template.spec.containers[].image}{"\n"}')" ]]; then
        echo "ERROR: cronjob $CRONJOB is not configured with the newest Floorist image"
        exit 1
    fi
done
