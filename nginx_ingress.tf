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