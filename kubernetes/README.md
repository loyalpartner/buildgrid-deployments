# BuildGrid Kubernetes deployment example

This directory contains configuration for deploying a working BuildGrid in
Kubernetes. This is intended to provide both a demo BuildGrid grid for
testing and experimenting with using BuildGrid, and a starting point for
creating a robust BuildGrid deployment in Kubernetes.

In addition to BuildGrid itself, this directory also contains config for
deploying services that this BuildGrid set up depends on. The additional
services are

- PostgreSQL, providing a database for the scheduler and indexed CAS
- Redis, providing storage for ActionCache data
- nginx, providing a cleartext reverse proxy through to the various BuildGrid
  services

## Topology

The BuildGrid services are deployed in three separate pods, allowing them
to be scaled horizontally as required. The pods are split such that one pod
provides the Execution, Operation, and Bots services, another provides the
CAS service, and the third provides the ActionCache service.

The deployment also contains a number of workers, using
`buildbox-run-bubblewrap` and `buildbox-run-hosttools`. These can also be
scaled by modifying the config, to do more work in parallel.

The PostgreSQL and Redis services are simply deployed to enable BuildGrid to
function and demonstrate its features.

Nginx is deployed as a reverse proxy to expose all the services in a single
place. It is deployed using a Deployment and a LoadBalancer Service rather
than using Ingress to enable cleartext gRPC for testing.

## Usage

### Deployment

Deploying the whole BuildGrid in one go is a case of running a single command

``` shell
kubectl create -Rf ./
```

This will deploy the following pods:

- PostgreSQL
- Redis
- Execution/Operations/Bots services
- CAS
- ActionCache
- buildbox-run-hosttools (3 replicas)
- buildbox-run-bubblewrap (3 replicas)
- nginx

Individual components can be deployed separately by being more specific about
which files to deploy,

``` shell
kubectl create -Rf postgres/
kubectl create -Rf redis/
kubectl create -Rf buildgrid/
kubectl create -Rf buildbox/
kubectl create -Rf nginx/
```

The replica counts of these pods can be increased or decreased as needed, except
the CAS. The CAS uses a persistent volume to store objects on disk, and so can't
have more than one replica (since all replicas would need to share the same disk).

Making the CAS scalable is left as an exercise to the reader as the solutions
require external resources. Some ideas are using an S3 bucket for storage (see
the S3 example in the docker-compose section of this repository, and
[the BuildGrid documentation][0] for guidance), or using NFS to make the
PersistentVolume work properly with shared write access.

[0]: https://buildgrid.build/developer/reference_api.html#buildgrid._app.settings.parser.S3


### Interaction

Get the URL of your endpoint using `kubectl get service nginx`. The instance
name of the deployed BuildGrid is `buildgrid`.

This can then used as a remote executor and remote cache in your favourite
REAPI client. Some examples of how this might look,

For [Bazel][1],

``` shell
bazel run --remote_executor=<endpoint url here> --remote_instance_name=buildgrid //:all
```

For [recc][2],

``` shell
RECC_SERVER=<endpoint url here> RECC_INSTANCE=buildgrid recc gcc -c hello.c -o hello.o
```

For [BuildStream][3] in `project.conf`,

``` yaml
remote-execution:
  execution-service:
    url: <endpoint url here>
    instance-name: buildgrid
  storage-service:
    url: <endpoint url here>
    instance-name: buildgrid
  action-cache-service:
    url: <endpoint url here>
    instance-name: buildgrid
```

You may need to specify a particular type of worker. This can be done by
setting the `runner` platform property in your client.

> NOTE: Currently BuildStream doesn't allow you to set custom platform
> properties. To use BuildStream you should remove any non-bubblewrap
> workers, with
>
> ``` shell
> kubectl delete -Rf buildbox/!(bubblewrap)
> ```

The available values for the `runner` property are

- `hosttools` (forces a [buildbox-run-hosttools][4] runner)
- `bubblewrap` (forces a [buildbox-run-bubblewrap][5] runner)

[1]: https://bazel.build/
[2]: https://gitlab.com/bloomberg/recc
[3]: https://buildstream.build/
[4]: https://gitlab.com/BuildGrid/buildbox/buildbox-run-hosttools/
[5]: https://gitlab.com/BuildGrid/buildbox/buildbox-run-bubblewrap/
