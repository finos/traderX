extension radius

param application string = 'traderx-state-005'

resource database 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'database'
  properties: {
    application: application
    container: {
      image: 'traderx/database:state004'
      ports: {
        tcp: { containerPort: 18082 }
        pg: { containerPort: 18083 }
        web: { containerPort: 18084 }
      }
    }
  }
}

resource referencedata 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'reference-data'
  properties: {
    application: application
    container: {
      image: 'traderx/reference-data:state004'
      ports: {
        web: { containerPort: 18085 }
      }
    }
  }
}

resource tradefeed 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-feed'
  properties: {
    application: application
    container: {
      image: 'traderx/trade-feed:state004'
      ports: {
        web: { containerPort: 18086 }
      }
    }
  }
}

resource peopleservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'people-service'
  properties: {
    application: application
    container: {
      image: 'traderx/people-service:state004'
      ports: {
        web: { containerPort: 18089 }
      }
    }
  }
}

resource accountservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'account-service'
  properties: {
    application: application
    container: {
      image: 'traderx/account-service:state004'
      ports: {
        web: { containerPort: 18088 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
        PEOPLE_SERVICE_HOST: { value: peopleservice.name }
      }
    }
    connections: {
      peopleservice: { source: peopleservice.id }
      database: { source: database.id }
    }
  }
}

resource positionservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'position-service'
  properties: {
    application: application
    container: {
      image: 'traderx/position-service:state004'
      ports: {
        web: { containerPort: 18090 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
      }
    }
    connections: {
      database: { source: database.id }
    }
  }
}

resource tradeservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-service'
  properties: {
    application: application
    container: {
      image: 'traderx/trade-service:state004'
      ports: {
        web: { containerPort: 18092 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
        PEOPLE_SERVICE_HOST: { value: peopleservice.name }
        ACCOUNT_SERVICE_HOST: { value: accountservice.name }
        REFERENCE_DATA_HOST: { value: referencedata.name }
        TRADE_FEED_HOST: { value: tradefeed.name }
      }
    }
    connections: {
      database: { source: database.id }
      peopleservice: { source: peopleservice.id }
      accountservice: { source: accountservice.id }
      referencedata: { source: referencedata.id }
      tradefeed: { source: tradefeed.id }
    }
  }
}

resource tradeprocessor 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-processor'
  properties: {
    application: application
    container: {
      image: 'traderx/trade-processor:state004'
      ports: {
        web: { containerPort: 18091 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
        TRADE_FEED_HOST: { value: tradefeed.name }
      }
    }
    connections: {
      database: { source: database.id }
      tradefeed: { source: tradefeed.id }
    }
  }
}

resource webfrontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'web-front-end-angular'
  properties: {
    application: application
    container: {
      image: 'traderx/web-front-end-angular:state004'
      ports: {
        web: { containerPort: 18093 }
      }
    }
    connections: {
      tradefeed: { source: tradefeed.id }
      accountservice: { source: accountservice.id }
      positionservice: { source: positionservice.id }
      tradeservice: { source: tradeservice.id }
      referencedata: { source: referencedata.id }
    }
  }
}

resource edgeproxy 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'edge-proxy'
  properties: {
    application: application
    container: {
      image: 'nginx:1.27-alpine'
      ports: {
        web: { containerPort: 8080 }
      }
    }
    connections: {
      database: { source: database.id }
      tradefeed: { source: tradefeed.id }
      peopleservice: { source: peopleservice.id }
      accountservice: { source: accountservice.id }
      positionservice: { source: positionservice.id }
      tradeservice: { source: tradeservice.id }
      tradeprocessor: { source: tradeprocessor.id }
      webfrontend: { source: webfrontend.id }
      referencedata: { source: referencedata.id }
    }
  }
}
