extension radius
extension radiusResources

// Parameters
param application string
param environment string

resource database 'Radius.Resources/postgreSQL@2023-10-01-preview' = {
  name: 'database'
  properties: {
    environment: environment
    application: application
    size: 'S'
  }
}

resource referencedata 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'reference-data'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/reference-data:latest'
      ports: {
        web: {
          containerPort: 18085
        }
      }
    }
  }
}

resource tradefeed 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-feed'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/trade-feed:latest'
      ports: {
        web: {
          containerPort: 18086
        }
      }
    }
  }
}

resource peopleservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'people-service'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/people-service:latest'
      ports: {
        web: {
          containerPort: 18089
        }
      }
    }
  }
}

resource accountservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'account-service'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/account-service:latest'
      ports: {
        web: {
          containerPort: 18088
        }
      }
      env: {
        DATABASE_HOST: {
          value: database.properties.host
        }
        DATABASE_PORT: {
          value: string(database.properties.port)
        }
        DATABASE_NAME: {
          value: database.properties.database
        }
        DATABASE_DBUSER: {
          value: database.properties.username
        }
        DATABASE_DBPASS: {
          value: database.properties.password
        }
        PEOPLE_SERVICE_HOST: {
          value: peopleservice.name
        }
      }
    }
    connections: {
      peopleservice: {
        source: peopleservice.id
      }
      db: {
        source: database.id
      }
    }
  }
}

resource positionservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'position-service'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/position-service:latest'
      ports: {
        web: {
          containerPort: 18090
        }
      }
      env: {
        DATABASE_HOST: {
          value: database.properties.host
        }
        DATABASE_PORT: {
          value: string(database.properties.port)
        }
        DATABASE_NAME: {
          value: database.properties.database
        }
        DATABASE_DBUSER: {
          value: database.properties.username
        }
        DATABASE_DBPASS: {
          value: database.properties.password
        }
      }
    }
    connections: {
      db: {
        source: database.id
      }
    }
  }
}

resource tradeservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-service'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/trade-service:latest'
      ports: {
        web: {
          containerPort: 18092
        }
      }
      env: {
        DATABASE_HOST: {
          value: database.properties.host
        }
        DATABASE_PORT: {
          value: string(database.properties.port)
        }
        PEOPLE_SERVICE_HOST: {
          value: peopleservice.name
        }
        ACCOUNT_SERVICE_HOST: {
          value: accountservice.name
        }
        REFERENCE_DATA_HOST: {
          value: referencedata.name
        }
        TRADE_FEED_HOST: {
          value: tradefeed.name
        }
      }
    }
    connections: {
      db: {
        source: database.id
      }
      peopleservice: {
        source: peopleservice.id
      }
      accountservice: {
        source: accountservice.id
      }
      referencedata: {
        source: referencedata.id
      }
      tradefeed: {
        source: tradefeed.id
      }
    }
  }
}

resource tradeprocessor 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-processor'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/trade-processor:latest'
      ports: {
        web: {
          containerPort: 18091
        }
      }
      env: {
        DATABASE_HOST: {
          value: database.properties.host
        }
        DATABASE_PORT: {
          value: string(database.properties.port)
        }
        DATABASE_NAME: {
          value: database.properties.database
        }
        DATABASE_DBUSER: {
          value: database.properties.username
        }
        DATABASE_DBPASS: {
          value: database.properties.password
        }
        TRADE_FEED_HOST: {
          value: tradefeed.name
        }
      }
    }
    connections: {
      db: {
        source: database.id
      }
      tradefeed: {
        source: tradefeed.id
      }
    }
  }
}

resource webfrontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'web-front-end-angular'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/web-front-end-angular:latest'
      ports: {
        web: {
          containerPort: 18093
        }
      }
      env: {
        DATABASE_HOST: {
          value: database.properties.host
        }
        DATABASE_PORT: {
          value: string(database.properties.port)
        }
      }
    }
    connections: {
      db: {
        source: database.id
      }
      tradefeed: {
        source: tradefeed.id
      }
    }
  }
}

resource ingress 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'ingress'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/willtsai/traderx/ingress:latest'
      ports: {
        web: {
          containerPort: 8080
        }
      }
      env: {
        DATABASE_HOST: {
          value: database.properties.host
        }
        DATABASE_PORT: {
          value: string(database.properties.port)
        }
      }
    }
    connections: {
      db: {
        source: database.id
      }
      tradefeed: {
        source: tradefeed.id
      }
      peopleservice: {
        source: peopleservice.id
      }
      accountservice: {
        source: accountservice.id
      }
      positionservice: {
        source: positionservice.id
      }
      tradeservice: {
        source: tradeservice.id
      }
      tradeprocessor: {
        source: tradeprocessor.id
      }
      webfrontend: {
        source: webfrontend.id
      }
    }
  }
}
