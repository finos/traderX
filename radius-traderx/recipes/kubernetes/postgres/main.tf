terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

variable "context" {
  description = "This variable contains Radius recipe context."
  type = any
}

variable "memory" {
  description = "Memory limits for the PostgreSQL container"
  type = map(object({
    memoryRequest = string
    memoryLimit  = string
  }))
  default = {
    S = {
      memoryRequest = "512Mi"
      memoryLimit   = "1024Mi"
    },
    M = {
      memoryRequest = "1Gi"
      memoryLimit   = "2Gi"
    }
  }
}

locals {
  uniqueName = var.context.resource.name
  port     = 5432
  namespace = var.context.runtime.kubernetes.namespace
}

resource "kubernetes_config_map" "postgresql_init" {
  metadata {
    name      = "${local.uniqueName}-init"
    namespace = local.namespace
  }

  data = {
    "01-init.sql" = file("${path.module}/../database/initialSchema.sql")
  }
}

resource "kubernetes_deployment" "database" {
  metadata {
    name      = local.uniqueName
    namespace = local.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          image = "postgres:15-alpine"
          name  = "database"
          resources {
            requests = {
              memory = var.memory[var.context.resource.properties.size].memoryRequest
            }
            limits = {
              memory = var.memory[var.context.resource.properties.size].memoryLimit
            }
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "sa"
          }
          env {
            name = "POSTGRES_USER"
            value = "sa"
          }
          env {
            name  = "POSTGRES_DB"
            value = "traderx"
          }
          port {
            container_port = local.port
          }
          volume_mount {
            name       = "init-scripts"
            mount_path = "/docker-entrypoint-initdb.d"
          }
        }
        volume {
          name = "init-scripts"
          config_map {
            name = kubernetes_config_map.postgresql_init.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgresql" {
  metadata {
    name      = local.uniqueName
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = local.port
      target_port = local.port
    }

    type = "ClusterIP"
  }
}

output "result" {
  value = {
    resources = [
      "/planes/kubernetes/local/namespaces/${kubernetes_service.postgresql.metadata[0].namespace}/providers/core/Service/${kubernetes_service.postgresql.metadata[0].name}",
      "/planes/kubernetes/local/namespaces/${kubernetes_deployment.postgresql.metadata[0].namespace}/providers/apps/Deployment/${kubernetes_deployment.postgresql.metadata[0].name}"
    ]
    values = {
      host     = "${kubernetes_service.postgresql.metadata[0].name}.${kubernetes_service.postgresql.metadata[0].namespace}.svc.cluster.local"
      port     = local.port
      database = "traderx"
      username = "sa"
    }
    secrets = {
      password = "sa"
    }
  }
}