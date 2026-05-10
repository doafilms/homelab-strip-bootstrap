# homelab-strip-bootstrap

Public bootstrap script for the **private** [doafilms/homelab-strip](https://github.com/doafilms/homelab-strip) repo.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/doafilms/homelab-strip-bootstrap/main/bootstrap.sh | bash
```

This script auto-installs Xcode CLT, Homebrew, `gh`, Tailscale, and Übersicht, then prompts for `gh auth login` and Tailscale sign-in, then clones the private app repo and runs its installer.

It's useless without (a) being signed into the right Tailscale tailnet and (b) having access to the private app repo via your GitHub account. So it's safe to leave public.

For the heartbeat host (the Mac that runs the server), pass `--server`:

```bash
curl -fsSL https://raw.githubusercontent.com/doafilms/homelab-strip-bootstrap/main/bootstrap.sh | bash -s -- --server
```
