# syntax=docker/dockerfile:1.7
#
# Ampbase Supervisor container image.
#
# The supervisor binary itself is built in the main monorepo's release
# workflow (ampbase-io/ampbase / .github/workflows/supervisor-release.yml)
# and published to https://ampbase.io/releases/{VERSION}/ampbase-{target}
# via Fly statics in front of a Tigris bucket. This Dockerfile downloads
# the released, checksummed binary and packages it into a minimal
# distroless image — there is no source-from-monorepo step here.
#
# Built multi-arch via buildx; the fetch stage runs on $BUILDPLATFORM
# (native, no QEMU) and the final stage is per-target. Verification
# against the published checksums.txt happens inside the fetch stage so
# a mismatch fails the build rather than shipping a tampered binary.

ARG VERSION

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS fetch
ARG TARGETARCH
ARG VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) target="x86_64-unknown-linux-musl" ;; \
      arm64) target="aarch64-unknown-linux-musl" ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    base="https://ampbase.io/releases/${VERSION}"; \
    curl -fsSL "${base}/ampbase-${target}" -o ampbase; \
    curl -fsSL "${base}/checksums.txt"      -o checksums.txt; \
    expected="$(grep " ampbase-${target}\$" checksums.txt | awk '{print $1}')"; \
    [ -n "$expected" ] || { echo "no checksum entry for ampbase-${target}" >&2; exit 1; }; \
    actual="$(sha256sum ampbase | awk '{print $1}')"; \
    [ "$expected" = "$actual" ] || { echo "checksum mismatch: expected ${expected}, got ${actual}" >&2; exit 1; }; \
    chmod +x ampbase

FROM gcr.io/distroless/static-debian12:latest
COPY --from=fetch /work/ampbase /usr/local/bin/ampbase
ENTRYPOINT ["/usr/local/bin/ampbase"]
