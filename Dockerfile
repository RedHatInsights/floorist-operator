FROM registry.redhat.io/openshift4/ose-ansible-rhel9-operator:v4.19.0@sha256:98c6b093520c1cbebd979cdc4503afbb739a8c84eaafd81b2b4f7c7c470477fd

USER root

RUN curl -L --output oc.tar.gz \
 https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux-amd64-rhel8.tar.gz && \
 tar -xvf oc.tar.gz oc && \
 mv oc /usr/local/bin/ && \
 rm oc.tar.gz

RUN export d=/etc/pki/ca-trust/source/blocklist; \
    trust extract --overwrite --format=pem-bundle \
    --filter='pkcs11:object=emSign%20ECC%20Root%20CA%20-%20G3;type=cert' \
    $d/emSign_ECC_Root_CA_-_G3.pem && \
    trust extract --overwrite --format=pem-bundle \
    --filter='pkcs11:object=Comodo%20AAA%20Services%20root;type=cert' \
    $d/Comodo_AAA_Services_root.pem && update-ca-trust

USER ${USER_UID}

COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY playbooks/ ${HOME}/playbooks/
COPY stage_test.sh ${HOME}/stage_test.sh
