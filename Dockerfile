# syntax=docker/dockerfile:1.7

ARG OTEL_VERSION=0.144.0
ARG GO_VERSION=1.25.0

FROM alpine:3.19 AS certs
RUN apk --no-cache add ca-certificates

FROM golang:${GO_VERSION} AS build-stage
ARG OTEL_VERSION
WORKDIR /build

COPY ./builder-config.yaml builder-config.yaml

# Install OCB (builder)
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    echo "Using OTEL_VERSION=${OTEL_VERSION}" && \
    GO111MODULE=on GOTOOLCHAIN=local \
    go install go.opentelemetry.io/collector/cmd/builder@v${OTEL_VERSION}

# Build the custom distribution (creates /build/<output_path>)
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    builder --config builder-config.yaml

# -------- ARTIFACT STAGE (export this to host) --------
# This contains the full generated folder (sources + binary).
FROM scratch AS artifact
# output_path from builder-config.yaml must match this folder name
COPY --from=build-stage /build/otelcol-custom /otelcol-custom

# -------- RUNTIME IMAGE STAGE (optional) --------
FROM gcr.io/distroless/base:latest AS runtime

ARG USER_UID=10001
USER ${USER_UID}

WORKDIR /otelcol
COPY ./collector-config.yaml /otelcol/collector-config.yaml
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --chmod=755 --from=build-stage /build/otelcol-custom /otelcol/otelcol-custom

ENTRYPOINT ["/otelcol/otelcol-custom"]
CMD ["--config", "/otelcol/collector-config.yaml"]

EXPOSE 4317 4318 12001
