[![FINOS Hosted Platform - TraderX demo](https://img.shields.io/badge/FINOS%20Hosted%20Platform-TraderX%20Demo-blue)](https://demo.traderx.finos.org/)
[![FINOS - Incubating](https://cdn.jsdelivr.net/gh/finos/contrib-toolbox@master/images/badge-incubating.svg)](https://finosfoundation.atlassian.net/wiki/display/FINOS/Incubating)

# FINOS | TraderX Example of a Simple Trading App

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](https://badgen.net/badge/local-dev/supported/green)

<img align="right" src="./docs/img/2023_TraderX_Vertical.png" alt="TraderX Logo" width="250"/>

TraderX is a Sample Trading Application, designed to be a distributed reference application 
in the financial services domain which can serve as a starting point for experimentation 
with various techniques and other open source projects.  It is designed to be simple
and accessible to developers of all backgrounds, with minimal pre-assumptions, and it 
can serve as a starting point for educational and experimentation purposes.

It is designed to be runnable from any developer workstation with minimal assumptions
other than Node, Java and Python runtimes. The libraries and toolkits it uses are meant
to be as vanilla as possible, to preserve its approachability by developers of all levels.

It contains Java, NodeJS, Python, .NET components that communicate over REST APIs and
messaging systems and are able to showcase a wide range of technical challenges to solve.

More detailed information about this project can be found in the website which is generated
from the code under the `docs` directory of this project.


## Project Demo and Overview Presentation

Learn more about the project - including a brief demo, in the Keynote Demo session 
that was presented at the [Open Source in Finance Forum 2023](https://events.linuxfoundation.org/open-source-finance-forum-new-york/)

[![TraderX Overview Video - OSFF 2023](./docs/img/2023_osff_video_thumb.png)](https://youtu.be/tSKDJlRYkm0?list=PLmPXh6nBuhJueQS5q-5IU3-0vmZEIUbz0&t=400)


## Project Components

The project consists of multiple moving parts, and you can see how things hang together by reviewing the architecture and sequence diagrams located in the [docs](docs) directory.


| *Component* | *Tech Stack* |*Description* |
| :--- | :--- | :--- |
| [docs](docs) | markdown | Architecture and Flow Diagrams are here! |
| [database](database) | java/h2 | A simple self-contained SQL database |
| [reference-data](reference-data) | node/nestjs | REST service (off a flat file) for querying ticker symbols |
| [trade-feed](trade-feed) | node/socketio | Message bus used for trade flows, as well as streaming to the GUI |
| [people-service](people-service) | .Net core | Service for looking up users, for account mangement |
| [account-service](account-service) | java/spring | Service for querying and validating accounts |
| [position-service](position-service) | java/spring | Position service for looking up positions and trades by the blotter |
| [trade-service](trade-service) | java/spring | Service for submitting trade/order requests for further processing |
| [trade-processor](trade-processor) | java/spring | Trade Feed consumer which processes trade/orders |
| [web-front-end](web-front-end) | html/angular or react | Interactive UI for executing trades and viewing blotter. Note: the AngularJS GUI was an initial contribution and contains account management capabilities. The React GUI was contributed during a hack day and may not work for managing accounts, but it does work for executing trades and viewing the blotter |

## Check out Code

This is installed locally through normal git clone operations.

```
git clone https://github.com/finos/traderX.git
```

## Run locally

There are a number of ways to run TraderX locally. You should choose the method you are most comfortable with.
- [Run locally manually](#run-locally-manually)
- [Run locally within a Corporate Environments](#run-locally-within-a-corporate-environments)
- [Run locally using Docker & Docker Compose](#run-locally-using-docker--docker-compose)
- [Run locally using Kubernetes](#run-locally-using-kubernetes)

## Run locally manually

In order to get things working together, it is recommended to select a range of ports to provide all running processes with, so that the pieces can interconnect as needed.  To run this all up 'by hand' here are default ports which are used, and you can easily export these variables to your favorite shell. 

```bash
export DATABASE_TCP_PORT=18082
export DATABASE_PG_PORT=18083
export DATABASE_WEB_PORT=18084
export REFERENCE_DATA_SERVICE_PORT=18085
export TRADE_FEED_PORT=18086
export ACCOUNT_SERVICE_PORT=18088
export PEOPLE_SERVICE_PORT=18089
export POSITION_SERVICE_PORT=18090
export TRADE_PROCESSOR_SERVICE_PORT=18091
export TRADING_SERVICE_PORT=18092
export WEB_SERVICE_ANGULAR_PORT=18093  #Angular
export WEB_SERVICE_REACT_PORT=18094  #React
```

The recommended starting sequence to let everything find what it needs is:

```bash
database
reference-data
trade-feed
people-service
account-service
position-service
trade-processor
trade-service
web-front-end
```

## Run locally within a Corporate Environments

When building locally in your company, if you are using a corporate artifact repository, you might need to override certain settings such as mavenCentral() in gradle, for the Java projects.

In order to do this, we have designated a `.gitignore`'d folder where you can leave company-specific build scripts. This folder is not managed by git and can be modified locally.

### Local Gradle Use Case

Create a `.corp` directory and in there you can create a `settings.gradle` file which will allow you to build all gradle projects

```sh
# in the traderX main directory
mkdir .corp
touch settings.gradle
```

The `settings.gradle` file should contain any overrides on your `repositories` and `plugins` block but should also contain these contents:

```groovy
rootProject.name = 'finos-traderX'
includeFlat 'database'
includeFlat 'account-service'
includeFlat 'position-service'
includeFlat 'trade-service'
includeFlat 'trade-processor'
```

This will include projects in directories at the same level as the .corp directory.

You can also store a separate gradle wrapper here, if you need the `distributionUrl` in your `gradle.properties`  to differ from the public internet one.

To build and run these projects, you can do the following:

```sh
###### From traderX root #####
# Note: gradle or ./gradlew can be used, depending on your path

gradle --settings-file .corp/settings.gradle build

# Build specific project
gradle --settings-file .corp/settings.gradle database:build

# Run specific project
gradle --settings-file .corp/settings.gradle account-service:bootRun

##### From inside the .corp directory ####
cd .corp
./gradlew build
./gradlew account-service:bootRun
```

## Run locally using Docker & Docker Compose

The easiest way to run up the entire system is using Docker Compose. This should work on your local computer using Docker Desktop / Docker Compose (tested on Mac Silicon) and also in Github Codespaces. 

### Codespaces
If using Github Codespaces it is recommended you select an 8-core type machine with 32GB RAM to ensure all the components have the required resources to start. 

To do this 
* Select the Green Code menu at the top of this page
* Select the Codespace tab then click the three dots '...' and select 'New with options...'.
* Change the machine type to '8-core' and click 'Create codespace'

As of writing, personal Github accounts receive 120 free core hours per month for using Codespaces, see the most recent details [here](https://docs.github.com/en/billing/managing-billing-for-github-codespaces/about-billing-for-github-codespaces#monthly-included-storage-and-core-hours-for-personal-accounts) 

Once you have cloned the repository locally or once your Codespace has started, from the root traderX directory run
```
docker compose up
```
On first run this will build all of the containers from the project specific Dockerfile's and then start them in the correct sequence.

The Docker containers are configured via Docker Compose to connect to a shred virtual network enabling them to communciate whether running on your local computer or via a Codespace.

Once everything has started the WebUI will be accessible at http://localhost:8080 (even if using a codespace, the localhost URL will be mapped through from your local browser to the Codespace).


## Run locally using Kubernetes

Another easy way to run up the entire system is using Kubernetes (K8s), which using [tilt.dev](https://tilt.dev) also allows you to easily swap in locally built images. The following are instructions to deploy all TraderX apps to your local enviroment using [tilt.dev](https://tilt.dev) and kustomize files.

### Prerequistes 
- Install and run [Docker](https://www.docker.com/products/docker-desktop/) or similar
- Install and run K8s - this could be one of the following well know distributions
    - [K8s with Docker Desktop](https://docs.docker.com/desktop/kubernetes/)
    - [Kind](https://kind.sigs.k8s.io/) 
    - [Minikube](https://minikube.sigs.k8s.io/docs/start/)
    - [k3s](https://k3s.io/) or similar
- Install an [Ingress Controller](https://kubernetes.github.io/ingress-nginx/deploy/) - this will need to match your k8s distribution
- Install [tilt.dev](https://tilt.dev)

### Preflight checks

```
kubectl get pods
```

You should see the kube pods as well as your ingress controller. Example below:

```
NAMESPACE       NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx   ingress-nginx-admission-create-6rh79        0/1     Completed   0          38s
ingress-nginx   ingress-nginx-admission-patch-f4kdg         0/1     Completed   1          38s
ingress-nginx   ingress-nginx-controller-7d4db76476-7wfl2   1/1     Running     0          38s
kube-system     coredns-7db6d8ff4d-ntdcr                    1/1     Running     0          4h8m
kube-system     coredns-7db6d8ff4d-ptfcs                    1/1     Running     0          4h8m
kube-system     etcd-docker-desktop                         1/1     Running     2          4h8m
kube-system     kube-apiserver-docker-desktop               1/1     Running     2          4h8m
kube-system     kube-controller-manager-docker-desktop      1/1     Running     2          4h8m
kube-system     kube-proxy-qt5z4                            1/1     Running     0          4h8m
kube-system     kube-scheduler-docker-desktop               1/1     Running     10         4h8m
kube-system     storage-provisioner                         1/1     Running     0          4h8m
```

### Start Tilt.dev

This command will deploy all the services to your local K8s environment.
Note: Ensure all the [pre-requistes](#prerequistes) are complete

After cloning the repo, you should `cd` into the folder (`cd traderx`)
```
# cd into gitops repo
cd ./gitops/local/

# Start Tilt
tilt up
```

Expected Console Output:
```
Tilt started on http://localhost:10350/
v0.30.2, built 2022-06-06

(space) to open the browser
(s) to stream logs (--stream=true)
(t) to open legacy terminal mode (--legacy=true)
(ctrl-c) to exit
```

This will download all the images and start them in your local k8s cluster. 

Launching the tilt.dev local webpage will allow you to monitor the progress by pressing the space bar. Or use one of the other options from the console.

Note: if you run `tilt up` and you get an error stating `template engine not found for: up.`. Your OS might be trying to run a ruby library, please check the tilt.dev installation instructions, or you path settings.


### Start Tilt.dev

### Local Developement

With all the services running you can then chose which ones you actively build locally.

If you go to your local [Tiltfile](./gitops/local/Tiltfile) you simply need to uncomment all the lines, or just for the respective applicaiton that you want to work on. Those applications will be built locally and deployed to your cluster instead of the host images. For example. In your local [Tiltfile](./gitops/local/Tiltfile) uncommenting the line for position_service will ask that Tilt.dev builds the images and your locally built image is deployed in your local k8s cluster in place of the prebuilt image from the Github Container Registry.

```
# Uncomment lines to use locally built version
# docker_build('ghcr.io/finos/traderx/database', './../../database/.')
# docker_build('ghcr.io/finos/traderx/account-service', './../../account-service/.')
# docker_build('ghcr.io/finos/traderx/people-service', './../../people-service/.')
docker_build('ghcr.io/finos/traderx/position-service', './../../position-service/.')
# docker_build('ghcr.io/finos/traderx/reference-data', './../../reference-data/.')
# docker_build('ghcr.io/finos/traderx/trade-feed', './../../trade-feed/.')
# docker_build('ghcr.io/finos/traderx/trade-processor', './../../trade-processor/.')
# docker_build('ghcr.io/finos/traderx/trade-service', './../../trade-service/.')
# docker_build('ghcr.io/finos/traderx/web-front-end-angular', './../../web-front-end/angular/.')
yaml = kustomize(('./traderx'))
print(yaml)
k8s_yaml(yaml)
```

### Clean up

Simply stop tilt and then run  `tilt down` 

# Getting Involved

### Project Meetings

A great way to interact with the TraderX community is to attend the bi-weekly Friday TraderX meetings.
Email help@finos.org to be added to the meeting invite directly, or find the meeting in the [FINOS Community Calendar](https://calendar.finos.org/).

## Contributing

1. Fork it (<https://github.com/finos/traderx/fork>)
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Read our [contribution guidelines](https://github.com/finos/traderx/blob/main/CONTRIBUTING.md) and [Community Code of Conduct](https://www.finos.org/code-of-conduct)
4. Commit your changes (`git commit -am 'Add some fooBar'`)
5. Push to the branch (`git push origin feature/fooBar`)
6. Create a new Pull Request

*NOTE:* Commits and pull requests to FINOS repositories will only be accepted from those contributors with an active, executed Individual Contributor License Agreement (ICLA) with FINOS OR who are covered under an existing and active Corporate Contribution License Agreement (CCLA) executed with FINOS. Commits from individuals not covered under an ICLA or CCLA will be flagged and blocked by the FINOS Clabot tool. Please note that some CCLAs require individuals/employees to be explicitly named on the CCLA.

*Need an ICLA? Unsure if you are covered under an existing CCLA? Email [help@finos.org](mailto:help@finos.org)*

## License

Copyright 2023 UBS, FINOS, Morgan Stanley

Distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

SPDX-License-Identifier: [Apache-2.0](https://spdx.org/licenses/Apache-2.0)
