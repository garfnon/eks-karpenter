resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # This is required to expose Istio Ingress Gateway
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [jsonencode(yamldecode(<<-EOT
      vpcId: ${var.vpc_id}
      replicaCount: 1
      tolerations:
        - key: "CriticalAddonsOnly"
          value: "true"
          effect: "NoSchedule"
      nodeSelector:
        nodeType: admin
    EOT
    ))]
  }

  helm_releases = {
    istio-base = {
      chart         = "base"
      chart_version = var.istio_chart_version
      repository    = var.istio_chart_url
      name          = "istio-base"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name
    }

    istiod = {
      chart         = "istiod"
      chart_version = var.istio_chart_version
      repository    = var.istio_chart_url
      name          = "istiod"
      namespace     = kubernetes_namespace_v1.istio_system.metadata[0].name
      values = [file("${path.module}/istiod-values.tftpl")]
    }

    # istio-ingress = {
    #   chart            = "gateway"
    #   chart_version    = var.istio_chart_version
    #   repository       = var.istio_chart_url
    #   name             = "istio-ingress"
    #   namespace        = "istio-ingress" # per https://github.com/istio/istio/blob/master/manifests/charts/gateways/istio-ingress/values.yaml#L2
    #   create_namespace = true
    #   values = [file("${path.module}/istio-ingress-values.tftpl")]
    # }
  }

  tags = var.tags
}

# Istio Ingress Gateway - separating from the EKS Blueprints Addons module for now because of race condition causing istio_gateway not to start properly.
resource "time_sleep" "delay" {
  create_duration = "15s"

  depends_on = [module.eks_blueprints_addons]
}

resource "helm_release" "istio_gateway" {
  chart       = "gateway"
  version     = var.istio_chart_version
  repository  = var.istio_chart_url
  name        = "istio-ingress"
  namespace   = "istio-ingress"
  create_namespace = true
  values = [file("${path.module}/istio-ingress-values.tftpl")]

  depends_on = [time_sleep.delay]
}

resource "kubectl_manifest" "istio_ingressclass" {
  yaml_body = <<-YAML
  apiVersion: networking.k8s.io/v1
  kind: IngressClass
  metadata:
    name: istio
    annotations:
      ingressclass.kubernetes.io/is-default-class: "true"
  spec:
    controller: istio.io/ingress-controller
  YAML

  depends_on = [
    helm_release.istio_gateway
  ]
}

data "kubernetes_service" "istio-ingressgateway" {
  metadata {
    name      = "istio-ingress"
    namespace = "istio-ingress"
  }
}

output "istio-ingressgateway" {
  value = data.kubernetes_service.istio-ingressgateway.status.0.load_balancer.0.ingress.0.hostname
}

resource "aws_route53_record" "istio_ingress_cname" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "*.${var.cluster_subdomain}"
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.istio-ingressgateway.status.0.load_balancer.0.ingress.0.hostname]

  depends_on = [helm_release.istio_gateway]
}

data "aws_route53_zone" "this" {
  name = "example.com"
}

# resource "null_resource" "apply_istio_addons" {
#   provisioner "local-exec" {
#     command = "kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/tags/${var.istio_chart_version}/samples/addons"
#   }

#   depends_on = [module.eks_blueprints_addons]
# }

# kiali TODO
# helm install     --set cr.create=true     --set cr.namespace=istio-system     --set cr.spec.auth.strategy="anonymous"     --namespace kiali-operator     --create-namespace     kiali-operator     kiali/kiali-operator
