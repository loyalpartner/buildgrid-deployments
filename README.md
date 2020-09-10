# BuildGrid deployment examples

This repository contains examples of different approaches to deploying
[BuildGrid][0], ranging from a simple single-node Remote Execution service
using docker-compose to a Kubernetes deployment demonstrating independently
scalable services.

[0]: https://buildgrid.build/


## docker-compose

The `docker-compose` directory contains a number of example deployments for
use with docker-compose. The aim is to provide a selection of demo deployment
which allow testing and experimentation with BuildGrid's features.

See the README.md file in that directory for detailed information on each
example.

### Basic Usage

``` shell
docker-compose -f docker-compose/redis-backed.yaml up
```

This spins up a single-node BuildGrid which uses Redis to store CAS and
ActionCache data.


## Kubernetes

The `kubernetes` directory contains an example Kubernetes deployment of
BuildGrid, with independently scalable services running behind a proxy
which provides a single endpoint to access the grid.

This example also contains multiple types of worker, using the various
`buildbox-run-*` runners. The worker type can be selected using a platform
property.

See the README.md file in that directory for detailed information on this
example.

### Basic Usage

``` shell
kubectl create -Rf kubernetes/
```

This spins up the whole BuildGrid service in your configured Kubernetes
cluster. Run `kubectl get service nginx` to get the URL to use to access
the deployed remote execution service.
