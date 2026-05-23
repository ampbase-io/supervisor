# Ampbase Supervisor

Universal [OpAMP](https://opentelemetry.io/docs/specs/opamp/) supervisor for
managing observability agents at scale. Speaks OpAMP to the
[Ampbase](https://ampbase.io) control plane and supervises one or more local
agent processes — Fluent Bit, Vector, OpenTelemetry Collector, Telegraf, or
Refinery — receiving remote config, applying it safely, and reporting back
health and effective configuration.

This repository hosts the **container image build** for the supervisor. The
supervisor binary itself is built and released from the Ampbase monorepo;
this repo consumes the released binaries from
[`https://ampbase.io/releases`](https://ampbase.io/releases) and packages
them into a multi-arch image published to
[`ghcr.io/ampbase-io/supervisor`](https://github.com/ampbase-io/supervisor/pkgs/container/supervisor).

## Install

### Linux (curl | sh)

The simplest path on a Linux host:

```bash
curl -fsSL https://ampbase.io/install.sh | sh
```

The installer detects your architecture, downloads the matching binary from
`https://ampbase.io/releases/<version>/ampbase-<target>`, verifies its
SHA-256 against the published `checksums.txt`, installs it to
`/usr/local/bin/ampbase`, and drops a systemd unit at
`/etc/systemd/system/ampbase.service` if `systemctl` is present.

After install, write your `supervisor.yaml` to `/etc/ampbase/` and start it:

```bash
sudo systemctl enable --now ampbase
```

### Docker

```bash
docker pull ghcr.io/ampbase-io/supervisor:v0.1.0
```

Run with a mounted config:

```bash
docker run --rm \
  -v "$(pwd)/supervisor.yaml:/etc/ampbase/supervisor.yaml:ro" \
  ghcr.io/ampbase-io/supervisor:v0.1.0 \
  --config /etc/ampbase/supervisor.yaml
```

The image is `gcr.io/distroless/static-debian12`-based and runs as root by
default — the supervisor frequently needs to write paths like
`/etc/otelcol`, `/var/lib/<agent>`, and similar. Override with `--user` (or
`USER` in a downstream `Dockerfile`) if you want to drop privileges and
mount config dirs you own.

### Raw binary

Each release ships musl-static binaries for `x86_64-unknown-linux-musl` and
`aarch64-unknown-linux-musl`. Download directly and verify by hand:

```bash
VERSION="v0.1.0"
TARGET="x86_64-unknown-linux-musl"   # or aarch64-unknown-linux-musl

curl -fsSLO "https://ampbase.io/releases/${VERSION}/ampbase-${TARGET}"
curl -fsSLO "https://ampbase.io/releases/${VERSION}/checksums.txt"

sha256sum -c --ignore-missing checksums.txt
chmod +x "ampbase-${TARGET}"
sudo install "ampbase-${TARGET}" /usr/local/bin/ampbase
```

## Verifying releases

Container images are signed via [Sigstore](https://sigstore.dev/) keyless
OIDC and ship with a [SLSA](https://slsa.dev/) build provenance attestation
and a Syft-based SBOM attestation. No keys are managed by Ampbase or its
customers; verification trusts the GitHub Actions workflow identity of this
repo.

Verify the image signature (cosign):

```bash
cosign verify ghcr.io/ampbase-io/supervisor:vX.Y.Z \
  --certificate-identity-regexp '^https://github\.com/ampbase-io/supervisor/\.github/workflows/publish\.yml@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Verify the SLSA build provenance (GitHub CLI):

```bash
gh attestation verify --repo ampbase-io/supervisor \
  oci://ghcr.io/ampbase-io/supervisor:vX.Y.Z
```

Inspect the SBOM attestation:

```bash
docker buildx imagetools inspect \
  ghcr.io/ampbase-io/supervisor:vX.Y.Z \
  --format '{{ json .SBOM }}'
```

For binary releases, verify the SHA-256 against the published
`checksums.txt`:

```bash
sha256sum -c checksums.txt
```

## Documentation

User guides, configuration reference, and the supervisor's role in the
Ampbase architecture live at [ampbase.io/docs](https://ampbase.io/docs).

## Support

For bug reports, feature requests, and questions, contact
[support@ampbase.io](mailto:support@ampbase.io).

## License

Ampbase Supervisor is proprietary software licensed under the
[Ampbase Cloud Service Agreement](https://ampbase.io/terms). See
[`LICENSE`](LICENSE) for the notice baked into both the source and the
distributed binaries.
