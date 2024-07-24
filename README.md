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
   4. [OpenShift templates](#openshift-templates)
   5. [Trying it out](#trying-it-out)
   6. [Stage test](#stage-test)


## Description

Floorist Operator manages scheduling of metrics export using Postresql queries to S3 bucket(s).
The base component is the [Floorist tool](https://github.com/RedHatInsights/floorist]).

Exportable queries are set via CustomResource (CR) `FloorPlan`.
Operator then creates a `CronJob` with a daily schedule.


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
    chunksize: # optional chunk size (integer; default: 1000; 0 to disable)
  database:
    secretName: # name of the database secret
  objectStore:
    secretName: # name of the k8s secret with S3 credentials
  suspend: # option to suspend cronjobs (false by default)
  logLevel: # optional Python log level (default INFO)
  resources: # optional to set resource limits (the following are defaults)
    limits:
      cpu: 100m
      memory: 500Mi
    requests:
      cpu: 50m
      memory: 250Mi
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
  bucket: # the desired bucket
  endpoint: # an URL with schema/protocol (and port)
```

Database Secret needs to follow this format:
```yaml
apiVersion: v1
kind: Secret
data:
  db.host:
  db.port:
  db.user:
  db.password:
  db.name:
  db.admin_user:
  db.admin_password:
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

### Test environment

To have a test bed, first set up an example services within the `default` namespace.

```
# Generate Secrects
make minikube-secrets

# Apply Kustomized Configuration
minikube kubectl -- apply -k config/minikube
```

This will:
* generate two secret files for datbase and minio under `config/minikube/.secrets`
* deploy postgresql database
* deploy minio (as S3)
* create a bucket with createbucket Job
* inject example data to database with the populator Job

### Build and deploy

Build, push, and deploy floorist-operator
```
VERSION=SETOPERATORIMAGETAG make podman-build podman-push deploy
```
Replace `SETOPERATORIMAGETAG` with desired image tag for the operator.

Optionally, `IMAGE_TAG_BASE` can be set to use a custom container registry. For example `IMAGE_TAG_BASE=quay.io/yourusername/floorist-operator`.

### OpenShift templates

OpenShift utilizes [`Template`](https://docs.openshift.com/container-platform/4.7/openshift_images/using-templates.html)
resources.
Due to current limitation in some environments there was a `openshift-teplates` Makefile target created
along with the [`openshift_template_generator.rb`](config/plugins/openshift_template_generator.rb) tool.
The `openshift-teplates` target generates an OpenShift `Template` out of kustomized resources
configured within [`config/templated/`](config/templated/kustomization.yaml) and
[`config/stage_test/`](config/stage_test/kustomization.yaml) .

To (re)generate OpenShift templates for this operator and it's test job use:
```
make openshift-templates
```
The results are written in the `deploy_template.yaml` and `stage_test_template.yaml` files.

It is also possible to (re)generate only the operator's or only the test's template:

To (re)generate the operator's template:
```
make openshift-template
```
To (re)generate the test's template:
```
make openshift-stage-test-template
```

### Trying it out

Create a sample [`Floorplan`](config/samples/metrics_v1alpha1_floorplan.yaml) within `default` namespace named `floorplan-sample`:
```
minikube kubectl -- apply -f config/samples/metrics_v1alpha1_floorplan.yaml
```
and observe exisence of `floorist-floorplan-sample-exporter` CronJob.

It should look like this:
```
$ minikube kubectl -- get cronjob floorist-floorplan-sample-exporter
NAME                        SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
floorplan-sample-exporter   5 0 * * *   False     0        <none>          31s
```

To see it in action, trigger a manual job:
```
minikube kubectl -- create job floorist-floorplan-sample-exporter-manual --from=cronjob/floorist-floorplan-sample-exporter
```

Observe status of the worker pod:
```
minikube kubectl -- get pod -l 'job-name=floorist-floorplan-sample-exporter-manual'
```

### Stage test

For the purpose of testing before auto-promotion from staging to production environment we've developed a job with a
24h delay. This test job checks for the successful creation of cronjobs and jobs by the operator, it asserts
the successful completion of the jobs and compares the floorist images that the operator is configured with and the
one in use by the jobs.

It is possible to use the test locally, altough with the following limitation:
- Job names are not unique: each time the test is re-ran it needs to be deleted first

To run the test locally:
```
minikube kubectl -- apply -k config/stage_test/local/
```
or:
```
VERSION=SETOPERATORIMAGETAG make deploy-test
```

If you'd like to see the test pass:
  1. [install the operator](#installation)
  2. set up the [test environment](#test-environment)
  3. create a [sample cronjob](#trying-it-out) and be sure to manually trigger a job
  4. deploy the test using one of the commands above
