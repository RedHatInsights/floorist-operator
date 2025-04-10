FROM registry.redhat.io/openshift4/ose-ansible-rhel9-operator:v4.18.0@sha256:fbc920cd87112098c8c1eee4928557b66e6fd547373677aeb891122eaf5806b9

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
