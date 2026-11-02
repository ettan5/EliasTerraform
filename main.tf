terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "kubernetes" {
  config_path = "/etc/rancher/k3s/k3s.yaml"
}
resource "kubernetes_namespace_v1" "webb" {
  metadata {
    name = "webb"
  }
}

resource "kubernetes_deployment_v1" "my_nginx_" {
  metadata {
    name      = "local-nginx"
    namespace = kubernetes_namespace_v1.webb.metadata[0].name
    labels = {
      app = "webb"
    }

  }


  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "webb"
      }
    }


    template {
      metadata {
        labels = {
          app = "webb"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }

          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "my_nginx_service" {
  metadata {
    name      = "local-nginx-service"
    namespace = kubernetes_namespace_v1.webb.metadata[0].name
    labels = {
      app = "webb"
    }
  }


  spec {
    selector = {
      app = "webb"
    }

    port {
      port        = 8081
      target_port = 80
    }

    type = "LoadBalancer"
  }
}


resource "kubernetes_horizontal_pod_autoscaler_v2" "my_nginx_hpa" {
  metadata {
    name      = "local-nginx-hpa"
    namespace = kubernetes_namespace_v1.webb.metadata[0].name
    labels = {
      app = "webb"
    }
  }
  spec {
    min_replicas = 1
    max_replicas = 5
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.my_nginx_.metadata[0].name

    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}

