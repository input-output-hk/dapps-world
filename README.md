# Setting up Ops devshell
To manage services or access the postgres shell you will need to setup your github credentials for the ops devshell to authenticate you.

Create a personal access token on github.com with the entire `repo` and `workflow` scope: Settings -> Developer Settings -> Personal access tokens -> Tokens (classic) -> Generate new token (classic).

Copy the token from github and then open your ~/.netrc and add github credentials in the following format:

```

machine github.com login <github username> password <token>
machine api.github.com login <github username> password <token>
```

Then clone `input-output-hk/dapps-world` and run:

``` sh
nix develop .#x86_64-linux.automation.devshells.ops
```
or if you have direnv setup, create a `.envrc.local` file in the repo and add the following:

``` sh

DEVSHELL_TARGET=ops
```

`

`
Then you can enter the `ops` devshell in this repo: `nix develop .#ops`.

If it worked right you should be able to see the `NOMAD_TOKEN` with `env | grep NOMAD_TOKEN`.
# Nomad Web UI
To login to https://nomad.dapps.aws.iohkdev.io, run `nomad ui -authenticate`. You can also enter the token manually into that webiste if the command doesn't work. Make sure to login with your IOHK google account.

In this webiste, you can view logs and restart/manage individual jobs and tasks.

# Access shell for database or other tasks
To access the postgres shell with the DB sync and chain-indexer tables, you can use nomad-exec once your in the ops devshell.

Run `nomad-exec -s -n infra`, choose `database` then `patroni`. Look for the allocation with `infra-database:master` and choose that one.

Once your in the Debug shell run, `psql -h /alloc -U dba -d postgres`. All tables will be accessible from this user.

To access the shell of any marlowe service run `nomad-exec -s -n marlowe` and select the job and task.
