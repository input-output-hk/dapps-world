{
  inputs,
  cell,
}: let
  getTfNixosUrl = moduleName: "git::https://github.com/tweag/terraform-nixos.git//${moduleName}?ref=646cacb12439ca477c05315a7bfd49e9832bc4e3";
in {
  benchmark = {
    config,
    pkgs,
    lib,
    ...
  }: {
    backend.local.path = "plutus-benchmark.tfstate";
    terraform.required_providers.acme = {
      source = "getstackhead/acme";
      version = "= 1.5.0-patched2";
    };
    provider.aws.region = "us-east-1";
    provider.acme.server_url = "https://acme-v02.api.letsencrypt.org/directory";
    module.nixos_image = {
      source = getTfNixosUrl "aws_image_nixos";
      release = "20.09";
    };
    module."deploy_nixos" = {
      source = getTfNixosUrl "deploy_nixos";
      nixos_config = "plutus-benchmark";
      target_host = "\${aws_instance.machine.public_ip}";
      ssh_private_key_file = "\${local_file.machine_ssh_key.filename}";
      ssh_agent = false;
      flake = true;
    };
    resource."aws_security_group"."ssh_and_egress" = {
      ingress = [
        {
          description = "allow SSH connections";
          from_port = 22;
          to_port = 22;
          protocol = "tcp";
          cidr_blocks = ["0.0.0.0/0"];
          ipv6_cidr_blocks = ["::/0"];
          security_groups = [];
          prefix_list_ids = [];
          self = false;
        }
      ];

      egress = [
        {
          description = "general connections";
          from_port = 0;
          to_port = 0;
          protocol = "-1";
          cidr_blocks = ["0.0.0.0/0"];
          ipv6_cidr_blocks = ["::/0"];
          security_groups = [];
          prefix_list_ids = [];
          self = false;
        }
      ];
    };
    resource."tls_private_key"."state_ssh_key" = {
      algorithm = "RSA";
    };

    resource."local_file"."machine_ssh_key" = {
      sensitive_content = "\${tls_private_key.state_ssh_key.private_key_pem}";
      filename = "\${path.module}/secrets/plutus_benchmark_id_rsa.pem";
      file_permission = "0600";
    };

    resource."aws_key_pair"."generated_key" = {
      key_name = "generated-key-\${sha256(tls_private_key.state_ssh_key.public_key_openssh)}";
      public_key = "\${tls_private_key.state_ssh_key.public_key_openssh}";
    };

    resource."aws_instance"."machine" = {
      ami = "\${module.nixos_image.ami}";
      instance_type = "i4i.2xlarge";
      vpc_security_group_ids = ["\${aws_security_group.ssh_and_egress.id}"];
      key_name = config.resource.aws_key_pair.generated_key.key_name;
      root_block_device.volume_size = 250;
    };

    output."public_dns" = {
      value = "\${aws_instance.machine.public_dns}";
    };
  };
}
