resource "kubernetes_deployment" "juice_shop" {
  metadata {
    name = "juice-shop"

    labels = {
      app = "juice-shop"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "juice-shop"
      }
    }

    template {
      metadata {
        labels = {
          app = "juice-shop"
        }
      }

      spec {
        container {
          name  = "juice-shop"
          image = "bkimminich/juice-shop"

          port {
            container_port = 3000
          }
        }
      }
    }
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_service" "juice_shop" {
  metadata {
    name = "juice-shop-service"
  }

  spec {
    selector = {
      app = "juice-shop"
    }

    port {
      port        = 80
      target_port = 3000
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.juice_shop]
}