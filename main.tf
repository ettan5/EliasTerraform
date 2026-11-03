## This Terraform configuration sets up a Kubernetes deployment with an Nginx container, a LoadBalancer service, and a Horizontal Pod Autoscaler (HPA) in a specified namespace. It also includes variables for configuring the number of replicas and the external port for the service.
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0.0"
}
## specifies the Kubernetes provider configuration, including the path to the kubeconfig file for connecting to the Kubernetes cluster.
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
    replicas = 1
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
      port        = var.external_port
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

## Hpa that scales the deployment based on CPU utilization if the cpu utilization exceeds 50% 
resource "kubernetes_horizontal_pod_autoscaler_v2" "my_nginx_hpa" {
  metadata {
    name      = "local-nginx-hpa"
    namespace = kubernetes_namespace_v1.webb.metadata[0].name
    labels = {
      app = "webb"
    }
   
  }
  
  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
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

output "namespace" {
  description = "Appens namespace"
  value       = kubernetes_namespace_v1.webb.metadata[0].name
}

output "deployment_name" {
  description = "The name of the deployment"
  value       = kubernetes_deployment_v1.my_nginx_.metadata[0].name
}
output "repicas" {
  description = "The number of replicas for the deployment"
  value       = kubernetes_deployment_v1.my_nginx_.spec[0].replicas
}

