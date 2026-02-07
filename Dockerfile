# https://devcenter.heroku.com/articles/ruby-support#supported-runtimes
# Optimized multi-stage build

# Stage 1: Base image with system dependencies
FROM ruby:4.0.1-alpine AS base

LABEL maintainer="yannisjaquet@mac.com"
LABEL org.opencontainers.image.source="https://github.com/yannis/kasaharacup"

# Install runtime dependencies only
RUN apk add --no-cache \
  bash \
  git \
  postgresql-client \
  postgresql-dev \
  nodejs \
  npm \
  vips \
  tzdata \
  gcompat \
  graphviz \
  font-noto \
  fontconfig \
  yaml-dev \
  && rm -rf /var/cache/apk/*

RUN fc-cache -f

WORKDIR /app
ENV PATH="./bin:$PATH"

# Stage 2: Dependencies
FROM base AS dependencies

# Install build dependencies temporarily
RUN apk add --no-cache --virtual .build-deps \
  build-base \
  linux-headers

ENV RUBYGEMS_VERSION=4.0.3

# Copy only dependency files first (better layer caching)
COPY Gemfile Gemfile.lock ./

# Install Ruby gems
RUN gem update --system ${RUBYGEMS_VERSION} && \
    bundle config set --local force_ruby_platform true && \
    bundle install -j $(nproc) && \
    rm -rf /usr/local/bundle/cache/*.gem

# Install Node modules
COPY package.json yarn.lock ./
RUN npm install -g corepack && \
    corepack enable && \
    yarn install --immutable

# Clean up build dependencies
RUN apk del .build-deps

# Stage 3: Development (default)
FROM base AS development

# Copy dependencies from build stage
COPY --from=dependencies /usr/local/bundle /usr/local/bundle
COPY --from=dependencies /app/node_modules /app/node_modules

# Install and enable corepack to make yarn available
RUN npm install -g corepack && corepack enable

# Copy application code
COPY . .

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# Stage 4: Production
FROM base AS production

ENV RAILS_ENV=production \
    NODE_ENV=production

# Copy dependencies
COPY --from=dependencies /usr/local/bundle /usr/local/bundle

# Copy application code
COPY . .

# Precompile assets
# RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
