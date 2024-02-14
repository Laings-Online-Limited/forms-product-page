ARG ALPINE_VERSION=3.18
ARG RUBY_VERSION=3.2.2

ARG DOCKER_IMAGE_DIGEST=sha256:4c8b0ef9c990903aad87c7f4d99e2b41e553bc35c2a5e601f7f1b98016a42b90

FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION}@${DOCKER_IMAGE_DIGEST} AS base
ARG NODEJS_VERSION=18
ENV NODEJS_VERSION=${NODEJS_VERSION}

FROM base AS build

WORKDIR /app

RUN apk update
RUN apk upgrade --available
RUN apk add libc6-compat openssl-dev build-base libpq-dev nodejs=~${NODEJS_VERSION} npm git python3
RUN adduser -D ruby
RUN mkdir /node_modules && chown ruby:ruby -R /node_modules /app

USER ruby

COPY --chown=ruby:ruby Gemfile* ./

ARG BUNDLE_WITHOUT=development:test
RUN [ -z "$BUNDLE_WITHOUT" ] || bundle config set --local without "$BUNDLE_WITHOUT"
RUN bundle config set --local jobs "$(nproc)"

RUN bundle install

COPY --chown=ruby:ruby package.json package-lock.json ./
RUN npm ci --ignore-scripts

ARG RAILS_ENV
ENV RAILS_ENV="${RAILS_ENV:-production}" \
    PATH="${PATH}:/home/ruby/.local/bin" \
    USER="ruby" 

COPY --chown=ruby:ruby . .

# you can't run rails commands like assets:precompile without a secret key set
# even though the command doesn't use the value itself
RUN SECRET_KEY_BASE=dummyvalue rails vite:build_all

# Remove devDependencies once assets have been built
RUN npm ci --ignore-scripts --only=production

FROM base AS app

ENV RAILS_ENV="${RAILS_ENV:-production}" \
    PATH="${PATH}:/home/ruby/.local/bin" \
    USER="ruby" \
    SECRET_KEY_BASE="dummyvalue"

WORKDIR /app

RUN apk update
RUN apk upgrade --available
RUN apk add libc6-compat openssl-dev libpq tzdata

RUN adduser -D ruby
RUN chown ruby:ruby -R /app

USER ruby

COPY --chown=ruby:ruby bin/ ./bin
RUN chmod 0755 bin/*

COPY --chown=ruby:ruby --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=ruby:ruby --from=build /app /app

EXPOSE 3000

CMD ["/bin/sh", "-o", "xtrace", "-c", "rails s -b 0.0.0.0"]
