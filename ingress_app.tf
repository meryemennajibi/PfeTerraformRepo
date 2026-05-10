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