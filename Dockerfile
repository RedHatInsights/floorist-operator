FROM registry.redhat.io/openshift4/ose-ansible-rhel9-operator:v4.18.0@sha256:7fe57a9525a6ffeeac60c165c2a1614be3dba31dade8fdd11331a962597fe373

USER root

RUN curl -L --output oc.tar.gz \
 https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux-amd64-rhel8.tar.gz && \
 tar -xvf oc.tar.gz oc && \
 mv oc /usr/local/bin/ && \
 rm oc.tar.gz

USER ${USER_UID}

COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY playbooks/ ${HOME}/playbooks/
COPY stage_test.sh ${HOME}/stage_test.sh
