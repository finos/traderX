# Deploy TraderX Using Radius

Radius can be used to deploy and run the [TraderX](https://github.com/finos/traderX) application.

## Prerequisites

- Install and set up [Radius](https://docs.radapp.io/getting-started/) and local Kubernetes cluster
- Optionally set up an [Azure](https://docs.radapp.io/providers/azure/) or [AWS](https://docs.radapp.io/providers/aws/) provider and environment in Radius

## Setup Instructions

### Step 1: Initialize Radius

First, initialize Radius in this directory:
```bash
rad init
```

>Select `Yes` when prompted to setup an application in the current directory

### Step 2: Register PostgreSQL Resource Type

TraderX uses a custom PostgreSQL resource type that needs to be registered before deployment.

1. **Create the PostgreSQL resource type**:
```bash
rad resource-type create postgreSQL -f types/types.yaml
```

2. **Register the PostgreSQL recipe**:
```bash
rad recipe register default --environment default --resource-type Radius.Resources/postgreSQL --template-kind bicep --template-path ghcr.io/willtsai/recipes/postgresql:latest
```

3. **Verify the recipe is registered**:
```bash
rad recipe list
```

You should see the PostgreSQL recipe listed in the output under `Radius.Resources/postgreSQL`.

### Step 3: Deploy the Application

To deploy and run the app in your local environment:
```bash
rad run app.bicep
```

The application will be available at `http://localhost:8080` once all services are running.

## Optional: Deploy to Cloud Environments

If you have an Azure environment set up, you can deploy the app there as well (in this example the Azure environment is associated with the `prod-azure` workspace):
```bash
rad deploy app.bicep -w prod-azure
```

If you have an AWS environment set up, you can deploy the app there as well (in this example the AWS environment is associated with the `prod-aws` workspace):
```bash
rad deploy app.bicep -w prod-aws
```