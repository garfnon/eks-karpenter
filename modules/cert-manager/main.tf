resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "1.16.0"
  create_namespace = true

  values = [templatefile("${path.module}/cert-manager-values.tftpl", {
    role_arn = aws_iam_role.cert_manager.arn
  })]
}

resource "aws_iam_policy" "cert_manager_route53" {
  name        = "cert-manager-route53-${var.cluster_name}"
  description = "Policy for cert-manager to access Route53 for DNS validation"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:GetChange",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZonesByName"
        ],
        Resource = "*"
      }
    ]
  })
}

# resource "aws_iam_role" "cert_manager" {
#   name               = "cert-manager"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Service = "eks.amazonaws.com"
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

resource "aws_iam_role" "cert_manager" {
  name               = "cert-manager-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${var.current_account_id}:oidc-provider/${replace(var.eks_cluster_oidc_issuer, "https://", "")}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(var.eks_cluster_oidc_issuer, "https://", "")}:sub" = "system:serviceaccount:cert-manager:cert-manager"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cert_manager_policy_attachment" {
  policy_arn = aws_iam_policy.cert_manager_route53.arn
  role       = aws_iam_role.cert_manager.name
}

# Using staging API: https://acme-staging-v02.api.letsencrypt.org/directory
# When ready, use: server: https://acme-v02.api.letsencrypt.org/directory
resource "kubectl_manifest" "cert_manager_cluster_issuer" {
  yaml_body = <<-YAML
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-prod
  spec:
    acme:
      server: https://acme-staging-v02.api.letsencrypt.org/directory
      email: user@email.com
      privateKeySecretRef:
        name: letsencrypt-prod
      solvers:
      - dns01:
          route53:
            region: us-east-1
  YAML

  depends_on = [
    helm_release.cert_manager
  ]
}

# resource "kubectl_manifest" "cert_manager_certificate" {
#   yaml_body = <<-YAML
#   apiVersion: cert-manager.io/v1
#   kind: Certificate
#   metadata:
#     name: wildcard-app1-com
#     namespace: istio-ingress
#   spec:
#     secretName: wildcard-app1
#     issuerRef:
#       name: letsencrypt-prod
#       kind: ClusterIssuer
#     commonName: "*.app1.example.com"
#     dnsNames:
#     - "*.app1.example.com"
#   YAML

#   depends_on = [
#     kubectl_manifest.cert_manager_cluster_issuer
#   ]
# }

resource "kubectl_manifest" "cert_manager_certificate_istio" {
  yaml_body = <<-YAML
  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: wildcard-istio-example-com
    namespace: istio-ingress
  spec:
    secretName: wildcard-istio-example-com-tls
    issuerRef:
      name: letsencrypt-prod
      kind: ClusterIssuer
    commonName: "*.${var.cluster_subdomain}"
    dnsNames:
    - "*.${var.cluster_subdomain}"
  YAML

  depends_on = [
    kubectl_manifest.cert_manager_cluster_issuer
  ]
}
