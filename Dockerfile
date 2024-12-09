FROM registry.redhat.io/openshift4/ose-ansible-rhel9-operator:v4.17@sha256:89d316e428bb52a886985c6aeda54cc9292925e19b87c7f6a1f3554bc7b2bd1c

COPY .baseimagedigest ${HOME}

USER root

RUN dnf -y upgrade && \
    dnf -y clean all

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
