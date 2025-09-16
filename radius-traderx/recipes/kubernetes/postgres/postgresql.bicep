@description('Information about what resource is calling this Recipe')
param context object

@description('Name of the PostgreSQL database')
param database string = 'traderx'

@description('PostgreSQL username')
param user string = 'sa'

@description('PostgreSQL password')
@secure()
param password string = 'sa'

@description('Tag to pull for the postgres container image')
param tag string = '15-alpine'

@description('Memory limits for the PostgreSQL container')
var memory = {
  S: {
    memoryRequest: '256Mi'
    memoryLimit: '512Mi'
  }
  M: {
    memoryRequest: '512Mi'
    memoryLimit: '1Gi'
  }
  L: {
    memoryRequest: '1Gi'
    memoryLimit: '2Gi'
  }
}

extension kubernetes with {
  kubeConfig: ''
  namespace: context.runtime.kubernetes.namespace
} as kubernetes

var uniqueName = 'database-${uniqueString(context.resource.id)}'
var port = 5432

resource configMap 'core/ConfigMap@v1' = {
  metadata: {
    name: '${uniqueName}-init'
    namespace: context.runtime.kubernetes.namespace
  }
  data: {
    '01-init.sql': loadTextContent('../../../../database/initialSchema.sql')
  }
}

resource postgresql 'apps/Deployment@v1' = {
  metadata: {
    name: uniqueName
  }
  spec: {
    selector: {
      matchLabels: {
        app: 'postgresql'
        resource: context.resource.name
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'postgresql'
          resource: context.resource.name
          // Label pods with the application name so `rad run` can find the logs.
          'radapp.io/application': context.application == null ? '' : context.application.name
        }
      }
      spec: {
        containers: [
          {
            // This container is the running postgresql instance.
            name: 'database'
            image: 'postgres:${tag}'
            ports: [
              {
                containerPort: port
              }
            ]
            resources: {
              requests: {
                memory: memory[context.resource.properties.size].memoryRequest
              }
              limits: {
                memory: memory[context.resource.properties.size].memoryLimit
              }
            }
            env: [
              {
                name: 'POSTGRES_DB'
                value: database
              }
              {
                name: 'POSTGRES_USER'
                value: user
              }
              {
                name: 'POSTGRES_PASSWORD'
                value: password
              }
            ]
            volumeMounts: [
              {
                name: 'init-scripts'
                mountPath: '/docker-entrypoint-initdb.d'
              }
            ]
          }
        ]
        volumes: [
          {
            name: 'init-scripts'
            configMap: {
              name: configMap.metadata.name
            }
          }
        ]
      }
    }
  }
}

resource svc 'core/Service@v1' = {
  metadata: {
    name: uniqueName
    labels: {
      name: uniqueName
    }
  }
  spec: {
    type: 'ClusterIP'
    selector: {
      app: 'postgresql'
      resource: context.resource.name
    }
    ports: [
      {
        port: port 
      }
    ]
  }
}

output result object = {
  resources: [
    '/planes/kubernetes/local/namespaces/${svc.metadata.namespace}/providers/core/Service/${svc.metadata.name}'
    '/planes/kubernetes/local/namespaces/${postgresql.metadata.namespace}/providers/apps/Deployment/${postgresql.metadata.name}'
  ]
  values: {
    host: '${svc.metadata.name}.${svc.metadata.namespace}.svc.cluster.local'
    port: port
    database: database
    username: user
  }
  secrets: {
    #disable-next-line outputs-should-not-contain-secrets
    password: password
  } 
}
