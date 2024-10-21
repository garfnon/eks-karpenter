variable "karpenter_version" {
    type = string
}

variable "ecr_repo_username" {
    description = "ECR repo username to pull Karpenter docker image"
    type = string
    sensitive = true
}

variable "ecr_repo_password" {
    description = "ECR repo password to pull Karpenter docker image"
    type = string
    sensitive = true
}

variable "karpenter_service_account" {
    type = string
}

variable "karpenter_node_iam_role_name" {
    type = string
}

variable "karpenter_queue_name" {
    type = string
}

variable "eks_cluster_name" {
    type = string
}

variable "eks_cluster_endpoint" {
    type = string
}
