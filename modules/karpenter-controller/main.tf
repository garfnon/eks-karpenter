################################################################################
# Karpenter Helm chart & manifests
# Not required; just to demonstrate functionality of the sub-module
################################################################################

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = var.ecr_repo_username
  repository_password = var.ecr_repo_password
  chart               = "karpenter"
  # TODO: variablize
  version             = var.karpenter_version
  wait                = false

  values = [
    <<-EOT
    replicas: 2
    serviceAccount:
      name: ${var.karpenter_service_account}
    settings:
      clusterName: ${var.eks_cluster_name}
      clusterEndpoint: ${var.eks_cluster_endpoint}
      interruptionQueue: ${var.karpenter_queue_name}
    EOT
  ]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiSelectorTerms:
        - alias: bottlerocket@1.23.0
      role: ${var.karpenter_node_iam_role_name}
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 3Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
        - deviceName: /dev/xvdb
          ebs:
            volumeSize: 24Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.eks_cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.eks_cluster_name}
      tags:
        karpenter.sh/discovery: ${var.eks_cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        metadata:
          labels:
            nodeType: worker
        spec:
          nodeClassRef:
            name: default
            group: karpenter.k8s.aws
            kind: EC2NodeClass
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["t", "m", "r"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["t3a", "m7i-flex", "r7i"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["1", "2", "4", "8"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot"]
      limits:
        cpu: 40
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}
