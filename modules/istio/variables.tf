variable "cluster_name" {
    type        = string
}

variable "cluster_endpoint" {
    type        = string
}

variable "cluster_subdomain" {
    type        = string
}

variable "cluster_version" {
    type        = string
}

variable "oidc_provider_arn" {
    type        = string
}

variable "vpc_id" {
    type        = string
}

variable "istio_chart_url" {
    type        = string
}

variable "istio_chart_version" {
    type        = string
}

variable "tags" {}
