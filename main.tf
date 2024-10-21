################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "20.26.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_k8s_version

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {}
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    karpenter = {
      ami_type            = var.admin_nodegroup_ami_type
      ami_release_version = var.admin_nodegroup_ami_version
      instance_types      = [var.admin_nodegroup_instance_type]
      min_size            = var.admin_nodegroup_min_size
      max_size            = var.admin_nodegroup_max_size
      desired_size        = var.admin_nodegroup_desired_size
      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }
      labels = {
        nodeType = "admin"
      }
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_type = "gp3"
            # volume_size = 2
            # Throughput and IOPs mininmum values are 125/3000 respectively, and are the default values. Set higher to see changes.
            # iops        = 4000
            # throughput  = 150
          }
        }
        xvdb = {
          device_name = "/dev/xvdb"
          ebs = {
            volume_type = "gp3"
            # volume_size = 25
            # iops        = 4001
            # throughput  = 151
          }
        }
      }
      # enable_bootstrap_user_data = true
      # post_bootstrap_user_data = <<-EOT
      #   #!/bin/bash
      #   cd /tmp
      #   sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
      #   sudo systemctl enable amazon-ssm-agent
      #   sudo systemctl start amazon-ssm-agent
      # EOT
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols - Istio"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
    # TODO - Revisit to see if these are needed.
    ingress_nlb = {
      description = "Allow traffic from NLB to EKS nodes"
      protocol    = "TCP"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ingress_nlb_https = {
      description = "Allow HTTPS traffic from NLB to EKS nodes"
      protocol    = "TCP"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }



  # cluster_tags = merge(local.tags, {
  #   NOTE - only use this option if you are using "attach_cluster_primary_security_group"
  #   and you know what you're doing. In this case, you can remove the "node_security_group_tags" below.
  #  "karpenter.sh/discovery" = var.cluster_name
  # })

  node_security_group_tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.cluster_name
  })

  depends_on = [module.vpc]

  tags = local.tags
}

################################################################################
# Karpenter - sets up all necessary AWS resources to use the Karpenter Controller.
################################################################################

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true
  # # Used to attach additional IAM policies to the Karpenter controller IAM role
  # iam_role_policies = {
  #   AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  # }
  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = local.tags
}

module "eks_karpenter-controller" {
  source      = "./modules/karpenter-controller"
  karpenter_version             = var.karpenter_version
  ecr_repo_username             = data.aws_ecrpublic_authorization_token.token.user_name
  ecr_repo_password             = data.aws_ecrpublic_authorization_token.token.password
  karpenter_service_account     = module.karpenter.service_account
  karpenter_node_iam_role_name  = module.karpenter.node_iam_role_name
  karpenter_queue_name          = module.karpenter.queue_name
  eks_cluster_name              = module.eks.cluster_name
  eks_cluster_endpoint          = module.eks.cluster_endpoint
  depends_on                    = [module.eks]
}

module "eks_gp3" {
  source = "./modules/gp3"
  depends_on  = [module.eks]
}

module "eks_istio" {
  source = "./modules/istio"
  cluster_name        = module.eks.cluster_name
  cluster_endpoint    = module.eks.cluster_endpoint
  cluster_version     = module.eks.cluster_version
  cluster_subdomain   = var.cluster_subdomain
  oidc_provider_arn   = module.eks.oidc_provider_arn
  vpc_id              = module.vpc.vpc_id
  istio_chart_url     = var.istio_chart_url
  istio_chart_version = var.istio_chart_version

  tags = local.tags
  depends_on          = [module.eks]
}

module "eks_cert-manager" {
  source = "./modules/cert-manager"
  cluster_name            = var.cluster_name
  cluster_subdomain       = var.cluster_subdomain
  current_account_id      = local.account_id
  eks_cluster_oidc_issuer = module.eks.cluster_oidc_issuer_url

  depends_on              = [module.eks, module.eks_istio]
}