[![FINOS - Incubating](https://cdn.jsdelivr.net/gh/finos/contrib-toolbox@master/images/badge-incubating.svg)](https://finosfoundation.atlassian.net/wiki/display/FINOS/Incubating)

# FINOS | TraderX Example of a Simple Trading App

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

The Sample Trading Application is a usable simple yet distributed reference application
in the financial services domain which can be used for experimenting with various
techniques and other open source projects.  It is designed to be simple and accessible
to programmers of all backgrounds, and can serve as a starting point for educational
and experimentation purposes.

It is designed to be runnable from any developer workstation with minimal assumptions
other than Node, Java and Python runtimes.

It contains Java, NodeJS, Python, .NET components that communicate over REST APIs and
messaging systems and are able to showcase a wide range of technical challenges to solve.

More detailed information about this project can be found in the website which is generated
from the code under the `docs` directory of this project.

## Current Project Status

This is currently a Work-In-Progress. At the moment there are some components which are just placeholder API contracts for an implementation to be created, while others are already runnable reference implementations.

Below is a table on status, listed in the order things need to start up for the system to operate.

*Pleae note, that for things not yet implemented (or things you'd like to reimplement) the tech stack selected is a suggestion. Feel free to swap things out as you see fit!*

| *Component* | *Tech Stack* | *Status* | *Comment* |
| :--- | :--- | :---: | :--- |
| [docs](docs) | markdown | :white_check_mark: | Architecture and Flow Diagrams are here! |
| [database](database) | java/h2 | :white_check_mark: | |
| [reference-data](reference-data) | node/nestjs | :white_check_mark: | |
| [trade-feed](trade-feed) | node/socketio | :white_check_mark: | |
| [people-service](people-service) | .Net core | :white_check_mark:  | Initial implementation complete |
| [account-service](account-service) | java/spring | :white_check_mark: | Initial Checkin Complete |
| [position-service](position-service) | java/spring | :white_check_mark: | Initial Service Checked In |
| [trade-service](trade-service) | java/spring | :white_check_mark: | Initial Service Checked In |
| [trade-processor](trade-processor) | java/spring | :white_check_mark:  | Initial Implementation Checked in |
| [web-front-end](web-front-end) | html/angular or react | :white_check_mark: | Initial Implementation in React and Angular |

## Installation (WIP)

This section will be filled out once the code is in place.

## Usage example (WIP)

In order to get things working together, it is recommended to select a range of ports to provde all running processes with, so that the pieces can interconnect as needed.  A more advanced instance of this project would do things using container/service location abstractions.  Here's one such example convention.

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

## Development setup

At the moment, the repository has architecture documents and API schema doc documents.  When the code is populated in this repo, build instructions will be listed here.

## Roadmap

1. Submit architecture diagram, API Specifications, and Flow Diagrams
2. Submit a working, simple pub-sub engine to use with this demo
3. Submit working implementations of components

## Local Building (Company Specific)

When building locally, if you are using a corporate artifact repository, you might need to override certain settings such as mavenCentral() in gradle, for the Java projects.

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

## Contributing

1. Fork it (<https://github.com/finos/TraderX/fork>)
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Read our [contribution guidelines](.github/CONTRIBUTING.md) and [Community Code of Conduct](https://www.finos.org/code-of-conduct)
4. Commit your changes (`git commit -am 'Add some fooBar'`)
5. Push to the branch (`git push origin feature/fooBar`)
6. Create a new Pull Request

*NOTE:* Commits and pull requests to FINOS repositories will only be accepted from those contributors with an active, executed Individual Contributor License Agreement (ICLA) with FINOS OR who are covered under an existing and active Corporate Contribution License Agreement (CCLA) executed with FINOS. Commits from individuals not covered under an ICLA or CCLA will be flagged and blocked by the FINOS Clabot tool. Please note that some CCLAs require individuals/employees to be explicitly named on the CCLA.

*Need an ICLA? Unsure if you are covered under an existing CCLA? Email [help@finos.org](mailto:help@finos.org)*

## License

Copyright 2023 UBS, FINOS, Morgan Stanley

Distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

SPDX-License-Identifier: [Apache-2.0](https://spdx.org/licenses/Apache-2.0)
