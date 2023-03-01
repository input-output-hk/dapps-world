include "root" {
  path = "${find_in_parent_folders()}"
}

terraform {
  source = "../../../modules/dev-namespace"
}

locals {
  # Set kubernetes based providers
  k8s = read_terragrunt_config("../../k8s/k8s-addons.hcl")
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "eks" {
  config_path = "../../k8s/eks"

  mock_outputs = {
    cluster_id              = "cluster-name"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-3.amazonaws.com/id/0000000000000000"
  }
}

generate = local.k8s.generate

inputs = {
  cluster-name = dependency.eks.outputs.cluster_id
  usernames = ["kevin.biger", "medric"]
  role_name = "dapp-store-dev"
  group_name = "dapp-store-developers"
  namespaces = [
    "dapp-store-preview-dev",
    "dapp-store-preview-prod",
  ]
  k8s_user = "dapp-store-dev-user"
}
