# BuildGrid docker-compose examples

This directory contains a number of example BuildGrid deployments using
docker-compose. These examples demonstrate different features and
deployment approaches available in BuildGrid.

Other than `logstream.yaml`, all of these deployments expose the following
services at http://localhost:50051/:

- Execution
- Operations
- CAS
- ActionCache

## `redis-backed.yaml`

Usage:

``` shell
docker-compose -f redis-backed.yaml up --scale bots=10
```

A simple single-node BuildGrid deployment, which uses Redis to store
both CAS objects and ActionCache entries. This allows for scalable
CAS and ActionCache services, which in turn will allow the deployment
to scale to handling large numbers of concurrent connections.

Concurrent connections in a given BuildGrid deployment are limited to
the `thread-pool-size` defined in the configuration file. If your
deployment suffers from connections being rejected, then increasing this
number will likely help. However, at some point performance will begin
to break down, due to limitations in Python's threading model.

An alternative to spawning vast numbers of threads in BuildGrid is to
horizontally scale the services, which requires a PostgreSQL database
to store scheduler data and either Redis or S3 to store CAS blobs
and ActionCache entries. For latency reasons, Redis is a better solution
than S3 for the ActionCache, hence the choice in this example.

This configuration could be used as a useful starting point for
experimenting with horizontally scaled BuildGrid deployments.


## `independently-scalable-services.yaml`

Usage:

``` shell
docker-compose -f independently-scalable-services.yaml up --scale bots=10
```

A more complex deployment demonstrating the most basic BuildGrid
deployment which also has most of the REAPI/RWAPI services deployed in
separate processes. This is an alternative solution to overcoming the
limitations of `thread-pool-size`, by distributing the connections
required to execute an Action across multiple processes.

This example isn't quite maximally separated, the Operations service
could be split out from the Execution service, but there is likely only
value in that split at the moment if your use-case requires heavy usage
of the Operations service.

Since the CAS and ActionCache aren't using a shareable location to store
their data, the CAS and ActionCache services in this example aren't able
to be scaled. However, the other services can all be horizontally scaled
independently of one another, allowing the number of containers providing
each service to be scaled appropriately for the demand.

The Redis approach to CAS/ActionCache in `redis-backed.yaml` could be
applied here, to allow all services to be scaled.


## `s3-cas.yaml`

Usage:

``` shell
docker-compose -f s3-cas.yaml up --scale bots=10
```

This deployment is similar to `independently-scalable-services.yaml`,
except it uses the S3 API to store CAS blobs in a Minio container. This
mostly provides an example of how BuildGrid can be configured to interact
with S3-based storage.

This example also demonstrates the CAS indexing functionality, where an
index of the CAS contents is stored in PostgreSQL, and used to reply to
requests that don't require actually reading the blob from S3. This
index also stores the last access time of each blob, supporting the LRU
CAS cleanup daemon which is running in this example deployment.


## `grafana-monitoring.yaml`

Usage:

``` shell
docker-compose -f grafana-monitoring.yaml up --scale bots=10
```

This deployment has BuildGrid's monitoring functionality enabled, which
publishes metrics about the state of BuildGrid into a StatsD server. The
metrics are then displayed in dashboards by the Grafana instance served
at http://localhost:3000/.

This deployment is similar to `s3-cas.yaml`, in that the CAS uses Minio
to store blobs, and has cleanup enabled to allow testing cleanup-related
metrics.


## `logstream.yaml`

Usage:

``` shell
docker-compose -f logstream.yaml up
```

This simple deployment involves a single container to demonstrate and
test BuildGrid's support for the LogStream service. This is intended
for use with the `bgd logstream` commands, and the streaming-related
tools provided in [buildbox-tools][0].

This deployment doesn't provide remote caching or execution services.

[0]: https://gitlab.com/BuildGrid/buildbox/buildbox-tools
