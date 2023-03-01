include "root" {
  path = "${find_in_parent_folders()}"
}

terraform {
  source = "../../../modules/ci"
}

inputs = {
  authorized_repos = [
    "input-output-hk/dapp_store_be_microservices",
  ]
  iam_user       = "dapp-store-ci"
  iam_role       = "dapp-store-ci"
  ecr_repos = [
    "dapps-validation-service",
    "dapp-store-api",
    "oura",
  ]
}
