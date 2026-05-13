resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  set = [
    {
      name  = "controller.publishService.enabled"
      value = "true"
    },
    {
      name  = "controller.service.externalTrafficPolicy"
      value = "Local"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
      value = azurerm_kubernetes_cluster.aks.node_resource_group
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
      value = "true"
    }
  ]

  depends_on = [kubernetes_namespace.ingress_nginx]
}

resource "kubernetes_ingress_v1" "juice_shop" {
  metadata {
    name = "juice-shop-ingress"
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["app.juice.nip.io"]
      secret_name = "dummy-tls"
    }

    rule {
      host = "app.juice.nip.io"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "juice-shop-service"

              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.nginx_ingress,
    kubernetes_service.juice_shop,
    kubernetes_secret.dummy_tls
  ]
}