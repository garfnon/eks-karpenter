# Remove non encrypted default storage class
resource "kubernetes_annotations" "default-storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"

  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  provider = kubernetes
}

# Create the new wanted StorageClass and make it default
resource "kubernetes_storage_class" "gp3-enc" {
  metadata {
    name = "gp3-enc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    "encrypted" = "true"
    "fsType" = "ext4"
    "type" = "gp3"
  }

  provider = kubernetes
}