# Floorist Operator

Kubernetes Operator to manage scheduling of metrics export with [Floorist](https://github.com/RedHatInsights/floorist).

## TOC

1. [Description](#description)
   1. [Scheduling](#scheduling)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Development](#development)
   1. [Prerequisites](#prerequisites)
   2. [Test environment](#test-environment)
   3. [Build and deploy](#build-and-deploy)
   4. [OpenShift template](#openshift-template)
   5. [Trying it out](#trying-it-out)


## Description

Floorist Operator manages scheduling of metrics export using Postresql queries to S3 bucket(s).
The base component is the [Floorist tool](https://github.com/RedHatInsights/floorist]).

Exportable queries are set via CustomResource (CR) `FloorPlan`.
Operator then creates a `CronJob` (via [`ClowdApp`](https://github.com/RedHatInsights/clowder))
with a daily schedule.


Advantages of having Floorist managed within operator are:
* central configuration of Floorist version/image managed across all namespaces,
* ease of configuration,
* dynamic scheduling

The operator is build using [Ansible Operator SDK](https://sdk.operatorframework.io/docs/building-operators/ansible/)
leveraging [kubernetes.core.k8s](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_module.html) Ansible module.

### Scheduling

Each `FloorPlan` resource/instace will get a non-conflicting schedule assigned.
Schedule assignement is selected as the first available slot during a day in a predefined interval.
By default this interval is 5 minutes, configured via `schedule_step` Ansible variable (max value is 60).

Midninght (00:00) is by default reserved.
The first schedule starts at `00:05` (with default 5 min. interval).
Slot constraints can be set via `skip_schedules` Ansible variable.

There is an upper limit on the number of `FloorPlan`s which is by default **287**.
The formula for different settings is: `24 * (60 / schedule_step)`.

Schedule of a single `FloorPlan` stays constant for the whole duration of its lifetime.

## Installation

WARNING: The Floorist operator **requires [Clowder](https://github.com/RedHatInsights/clowder)** to be set up
on the kubernetes cluster.

Clone the source code:
```
git clone https://github.com/RedHatInsights/floorist-operator.git
```

As cluster admin apply kubernetes objects (with kustomize):
```
kubectl apply -k config/default/
```

alternatively with
```
VERSION=SETOPERATORIMAGETAG make deploy
```
by replacing `SETOPERATORIMAGETAG` with appropriate image tag of the operator.

## Usage

Metric exporting is set up by creating a [`FloorPlan`](config/crd/bases/metrics.console.redhat.com_floorplans.yaml) CR:

```yaml
apiVersion: metrics.console.redhat.com/v1alpha1
kind: FloorPlan
metadata:
  name: # name
spec:
  queries: # a list of a prefix-query pair
  - prefix: # S3 folder path within a bucket
    query: >- # exporting query
      SELECT column FROM table;
    chunksize: # optional chunk size (integer)
  envName: # name of a ClowdEnv (of Clowder)
  database:
    sharedDbAppName: # name of a ClowdApp to take the shared database from
  objectStore:
    bucketName: # name of the S3 bucket
    secretName: # name of the k8s secret with S3 credentials
```

See also [full sample](config/samples/metrics_v1alpha1_floorplan.yaml).
For all possible parameters check out [`FloorPlan`](config/crd/bases/metrics.console.redhat.com_floorplans.yaml) CustomResourceDefinition.

S3 kubernetes Secret needs to follow this format:
```yaml
apiVersion: v1
kind: Secret
data:
  aws_access_key_id:
  aws_region:
  aws_secret_access_key:
  bucket:
  endpoint: # an URL with schema/protocol (and port)
```

## Development

### Prerequisites

* [Podman](https://podman.io/)
* [Minikube](https://minikube.sigs.k8s.io/docs/start/)
  ```
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  minikube start
  ```
* [Clowder Operator](https://github.com/RedHatInsights/clowder)
  * Run [`./build/kube_setup.sh`](https://github.com/RedHatInsights/clowder/blob/master/build/kube_setup.sh) from Clowder repository
  * Apply manifest
    ```
    minikube kubectl -- apply -f https://github.com/RedHatInsights/clowder/releases/download/v0.32.0/clowder-manifest-v0.32.0.yaml --validate=false
    ```
    Beware of the version!

### Test environment

To have a test bed, first set up an example application within the `default` namespace.

```
minikube kubectl -- apply -k config/clowder
```

That includes:
* a `ClowdEnv` named `env-default` which ensures presence of postgresql database and minio
* a `ClowdApp` named `test-app` that connects to the database, creates tables and inserts some data

Next, the minio secret (named `env-default-minio`) needs to be patched to comply with the described
Secret [format](#usage).
```
minikube kubectl -- patch secret env-default-minio --type=json --patch-file config/clowder/minio/minio_secret_consitency.yaml
```

### Build and deploy

Build, push, and deploy floorist-operator
```
VERSION=SETOPERATORIMAGETAG make podman-build podman-push deploy
```
Replace `SETOPERATORIMAGETAG` with desired image tag for the operator.

### OpenShift template

OpenShift utilizes [`Template`](https://docs.openshift.com/container-platform/4.7/openshift_images/using-templates.html)
resources.
Due to current limitation in some environments there was a `openshift-teplate` Makefile target created
along with [`openshift_template_generator.rb`](config/plugins/openshift_template_generator.rb) tool.
The `openshift-teplate` target generates an OpenShift `Template` out of kustomized resources
configured within [`config/templated/`](config/templated/kustomization.yaml).

To (re)generate OpenShift template for this operator use:
```
make openshift-template
```
The result is writte in the `deploy_template.yaml` file.

### Trying it out

Create a sample [`Floorplan`](config/samples/metrics_v1alpha1_floorplan.yaml) within `default` namespace:
```
minikube kubectl -- apply -f config/samples/metrics_v1alpha1_floorplan.yaml
```
and observe exisence of `floorplan-sample-floorist` ClowdApp.

It should look like this:
```
$ minikube kubectl -- get app floorplan-sample-floorist
NAME                        READY   MANAGED   ENVNAME       AGE
floorplan-sample-floorist   0       0         env-default   2m
$ minikube kubectl -- get cronjob
NAME                                         SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
floorplan-sample-floorist-metrics-exporter   0 2 * * *   False     0        9h              2m
```

To see it in action, trigger a manual job:
```
minikube kubectl -- create job floorplan-sample-floorist-metrics-exporter-manual --from=cronjob/floorplan-sample-floorist-metrics-exporter
```

Observe status of the worker pod:
```
minikube kubectl -- get pod -l 'job-name=floorplan-sample-floorist-metrics-exporter-manual'
```
