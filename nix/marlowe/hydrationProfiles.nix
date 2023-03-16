{
  cell,
  inputs,
}: {
  workload-policies-marlowe-runtime = {
    tf.hydrate-cluster.configuration.locals.policies = {
      consul.marlowe-runtime = {
        # chain-indexer also needs to read the cardano config
        key_prefix."config/cardano" = {
          policy = "read";
          intentions = "deny";
        };
        session_prefix."" = {
          policy = "write";
          intentions = "deny";
        };
      };
      vault.marlowe-runtime = {
        path."kv/data/chainsync/*".capabilities = ["read" "list"];
        path."kv/metadata/chainsync/*".capabilities = ["read" "list"];
        path."kv/data/marlowe/*".capabilities = ["read" "list"];
        path."kv/metadata/marlowe/*".capabilities = ["read" "list"];
        path."consul/creds/marlowe-runtime".capabilities = ["read"];
      };
    };
    # FIXME: consolidate policy reconciliation loop with TF
    # PROBLEM: requires bootstrapper reconciliation loop
    # clients need the capability to impersonate the `db-sync` role
    services.vault.policies.client = {
      path."consul/creds/marlowe-runtime".capabilities = ["read"];
      path."auth/token/create/marlowe-runtime".capabilities = ["update"];
      path."auth/token/roles/marlowe-runtime".capabilities = ["read"];
    };
  };
}
