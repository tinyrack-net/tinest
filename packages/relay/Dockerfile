FROM dart:3.13.2@sha256:18cbfc2ede913addb75d3a4cd1dbc9288ba138e3fc76414dd864b2c847779f79 AS build
WORKDIR /src
COPY packages/relay/docker/workspace_pubspec.yaml pubspec.yaml
COPY packages/relay/docker/pubspec.lock pubspec.lock
COPY packages/relay/pubspec.yaml relay/pubspec.yaml
COPY packages/relay/bin relay/bin
COPY packages/relay/lib relay/lib
COPY packages/relay_protocol/pubspec.yaml relay_protocol/pubspec.yaml
COPY packages/relay_protocol/lib relay_protocol/lib
RUN dart pub get --enforce-lockfile \
    && mkdir -p /out \
    && dart compile exe relay/bin/tinest_relay.dart -o /out/tinest-relay

FROM gcr.io/distroless/cc-debian12:nonroot@sha256:fccdbb0a547c14e23fcf4ce8ad62ca5d43b4faae8d22cd292f490fef9946c96e
COPY --from=build /out/tinest-relay /tinest-relay
EXPOSE 8080
ENTRYPOINT ["/tinest-relay"]
