variable "cluster_name" {
    type        = string
    description = "Name used for the project, e.g. RAVEn, SPEED..."
}

variable "cluster_k8s_version" {
    type        = string
    description = "EKS cluster Kubernetes version"
    default     = "1.31"
}

variable "cluster_subdomain" {
    type        = string
    description = "Subdomain used for this EKS cluster, e.g. cluster1.example.com"
}

variable "region" {
    type        = string
    description = "AWS region to deploy to"
}

variable "admin_nodegroup_instance_type" {
    type        = string
    description = "Admin nodegroup instance type"
    default     = "t3a.medium"
}

variable "admin_nodegroup_ami_type" {
    type        = string
    description = "Admin nodegroup AMI type"
    default     = "BOTTLEROCKET_x86_64"
}

variable "admin_nodegroup_ami_version" {
    type        = string
    description = "Admin nodegroup AMI version"
}

variable "admin_nodegroup_min_size" {
    type        = number
    description = "Admin nodegroup minimum size"
    default     = 1
}

variable "admin_nodegroup_max_size" {
    type        = number
    description = "Admin nodegroup maximum size"
    default     = 2
}

variable "admin_nodegroup_desired_size" {
    type        = number
    description = "Admin nodegroup desired size"
    default     = 2
}

variable "istio_chart_url" {
    type        = string
    description = "Istio Helm chart repo url"
    default     = "https://istio-release.storage.googleapis.com/charts"
}

variable "istio_chart_version" {
    type        = string
    description = "Istio Helm chart repo version"
    default     = "1.23.2"
}

variable "karpenter_version" {
    type        = string
    description = "Karpenter Helm chart repo version"
    default     = "1.0.6"
}
