# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  account_name   = "lace-prod"
  aws_account_id = "926093910549"
  #  aws_caller_arn = get_aws_caller_identity_arn()
  aws_profile = "lw"
  name        = "lace"
  project     = "lace"
  # Allow users to access k8s over aws_auth config
  users = [
    # QA
    "daniele.ricci",
    "dmytro.iakymenko",
    "ivaylo.andonov",
    # SRE
    "gytis.ivaskevicius",
    "daniel.thagard",
    "yuriy.taraday",
    "david.arnold",
    # TODO: Would be nice to autogenerate these
    "vault-github-employees-blaggacao-admin-1676566011-Zfgao21A3pkuZs",
    "vault-github-employees-gytis-ivaskevicius-admin-1676911560-EhdYB",
    "vault-github-employees-tshaynik-admin-1673297665-kUaLIODjr5KizK3",
    "vault-github-employees-YorikSar-admin-1674060998-05VaKR1K8aSptNa"
  ]
  domain = "lw.iog.io"
}
