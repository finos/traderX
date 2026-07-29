extension radius

param application string = 'traderx-state-010'

resource database 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'database'
  properties: {
    application: application
    container: {
      image: 'postgres:16-alpine'
      ports: {
        web: { containerPort: 5432 }
      }
    }
  }
}

resource natsbroker 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'nats-broker'
  properties: {
    application: application
    container: {
      image: 'nats:2.14-alpine'
      ports: {
        web: { containerPort: 4222 }
      }
    }
  }
}

resource referencedata 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'reference-data'
  properties: {
    application: application
    container: {
      image: 'traderx/reference-data:state009'
      ports: {
        web: { containerPort: 18085 }
      }
    }
  }
}

resource peopleservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'people-service'
  properties: {
    application: application
    container: {
      image: 'traderx/people-service:state009'
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
      image: 'traderx/account-service:state009'
      ports: {
        web: { containerPort: 18088 }
      }
    }
  }
}

resource positionservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'position-service'
  properties: {
    application: application
    container: {
      image: 'traderx/position-service:state009'
      ports: {
        web: { containerPort: 18090 }
      }
    }
  }
}

resource tradeprocessor 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-processor'
  properties: {
    application: application
    container: {
      image: 'traderx/trade-processor:state009'
      ports: {
        web: { containerPort: 18091 }
      }
    }
  }
}

resource tradeservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-service'
  properties: {
    application: application
    container: {
      image: 'traderx/trade-service:state009'
      ports: {
        web: { containerPort: 18092 }
      }
    }
  }
}

resource pricepublisher 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'price-publisher'
  properties: {
    application: application
    container: {
      image: 'traderx/price-publisher:state009'
      ports: {
        web: { containerPort: 18100 }
      }
    }
  }
}

resource ordermatcher 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'order-matcher'
  properties: {
    application: application
    container: {
      image: 'traderx/order-matcher:state009'
      ports: {
        web: { containerPort: 18110 }
      }
    }
  }
}

resource webfrontendangular 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'web-front-end-angular'
  properties: {
    application: application
    container: {
      image: 'traderx/web-front-end-angular:state009'
      ports: {
        web: { containerPort: 18093 }
      }
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
  }
}
