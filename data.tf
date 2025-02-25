data "aws_caller_identity" "current" {}

# data "aws_eks_cluster" "cluster" {
#   name = module.eks.cluster_name
# }

data "aws_availability_zones" "available" {}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr_token
}