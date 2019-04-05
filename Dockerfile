FROM elixir:1.8-alpine

ARG APP_NAME=chatbot
ARG PHOENIX_SUBDIR=.
ENV MIX_ENV=prod REPLACE_OS_VARS=true TERM=xterm
WORKDIR /opt/app

# Install nodejs for asset processing.
RUN apk update \
    && apk --no-cache --update add nodejs nodejs-npm

# Download and compile elixir dependencies.
COPY mix.* ./
RUN mix local.rebar --force \
    && mix local.hex --force
RUN mix do deps.get, deps.compile

# Run the static asset processing pipeline
COPY assets assets
RUN cd ${PHOENIX_SUBDIR}/assets \
    && npm install \
    && ./node_modules/brunch/bin/brunch build -p \
    && cd .. \
    && mix phx.digest

# Compile the application and build a release
COPY . .
RUN mix compile
RUN mix release --env=prod --verbose \
    && mv _build/prod/rel/${APP_NAME} /opt/release \
    && mv /opt/release/bin/${APP_NAME} /opt/release/bin/start_server


FROM alpine:3.9
RUN apk update && apk --no-cache --update add bash openssl-dev libssl1.1
ENV PORT=8080 MIX_ENV=prod REPLACE_OS_VARS=true
WORKDIR /opt/app

# Copy just the built artifact to the runnable image
COPY --from=0 /opt/release .
ENV RUNNER_LOG_DIR /var/log
CMD ["/opt/app/bin/start_server", "foreground", "boot_var=/tmp"]
