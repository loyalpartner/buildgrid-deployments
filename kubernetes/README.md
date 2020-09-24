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
REAPI client.

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

- `hosttools` (forces a [buildbox-run-hosttools][1] runner)
- `bubblewrap` (forces a [buildbox-run-bubblewrap][2] runner)
- `userchroot` (forces a [buildbox-run-userchroot][3] runner)

Some examples of how this might look,

For [Bazel][4],

``` shell
bazel run --remote_executor=<endpoint url here> --remote_instance_name=buildgrid //:all
```

For [recc][5],

``` shell
RECC_SERVER=<endpoint url here> RECC_INSTANCE=buildgrid recc gcc -c hello.c -o hello.o
```

For [BuildStream][6] in `project.conf`,

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

[1]: https://gitlab.com/BuildGrid/buildbox/buildbox-run-hosttools/
[2]: https://gitlab.com/BuildGrid/buildbox/buildbox-run-bubblewrap/
[3]: https://gitlab.com/BuildGrid/buildbox/buildbox-run-userchroot/
[4]: https://bazel.build/
[5]: https://gitlab.com/bloomberg/recc
[6]: https://buildstream.build/


### Specifying a custom execution environment

The workers run in a docker image based on the `debian:buster` image. It might
be desireable to execute Actions in a custom environment, such as a docker
image which contains all the required build dependencies.

Whilst BuildBox doesn't currently have a runner implementation which uses a
docker container to execute Actions, similar behaviour can be attained using
`buildbox-run-userchroot`. It just requires an extra setup step to convert
the docker image to a chroot usable by `buildbox-run-userchroot`.

This approach needs a couple of extra utilities, namely `chrootbuilder` from
[buildbox-tools][7], and `casupload` from [the recc repository][8].


#### Creating the chroot

First, pull the docker image you plan to use as a chroot. Any docker image
should work here, so a custom image could be created pretty trivially if
needed. This example uses a gcc docker image.

``` shell
docker pull gcc:10.2.0
```

The `chrootbuilder` tool can then be used to turn this docker image into a
directory usable by userchroot.

``` shell
chrootbuilder -e gcc:10.2.0 gcc-10
```

This will extract the contents into the `focal` directory. This directory
is our chroot directory, so it needs to be available in CAS for workers
to fetch and use.


#### Uploading the chroot

Uploading a directory to CAS can be done using the `casupload` tool.

``` shell
RECC_CAS_SERVER=<cas url here> RECC_INSTANCE=buildgrid casupload gcc-10
```

This command will return a digest which can be used when running `recc` to
specify a chroot to build in.


#### Using the chroot with recc

Since the root of the chroot isn't writeable, the `RECC_WORKING_DIR_PREFIX`
needs to be set, to encourage `recc` to write its outputs in a writeable
directory.

The `RECC_PREFIX_MAP` variable is set here to rewrite the `/usr/bin/gcc`
in the command into `/usr/bin/local/gcc` in the command sent to the remote
execution service. This is needed in this example since the docker image
used to generate the chroot has `/usr/bin/local/gcc` but not `/usr/bin/gcc`,
and the compiler command is required to use an absolute path.

``` shell
export RECC_SERVER=<endpoint url here>
export RECC_INSTANCE=buildgrid
export RECC_PROJECT_ROOT=project/
export RECC_PREFIX_MAP=/usr/bin=/usr/local/bin
export RECC_REMOTE_PLATFORM_runner=userchroot
export RECC_REMOTE_PLATFORM_chrootRootDigest=<chroot digest here>
recc /usr/bin/gcc -c project/hello.c -o project/hello.o
```
