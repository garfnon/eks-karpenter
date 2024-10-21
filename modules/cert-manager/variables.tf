variable "current_account_id" {
    type        = string
    description = "Current account ID to construct EKS cluster endpoint URL"
}

variable "eks_cluster_oidc_issuer" {
    type        = string
    description = "EKS cluster OIDC issuer ID to construct EKS cluster endpoint URL"
}

variable "cluster_name" {
    type        = string
    description = "EKS cluster name"
}

variable "cluster_subdomain" {
    type        = string
    description = "Subdomain for Letsencrypt wildcard cert"
}