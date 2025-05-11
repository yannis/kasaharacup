# https://devcenter.heroku.com/articles/ruby-support#supported-runtimes
FROM ruby:3.4.3-alpine
ENV RUBYGEMS_VERSION=3.6.7

FROM ruby:3.4.3-alpine
LABEL mainainer="yannisjaquet@mac.com"
LABEL org.opencontainers.image.source="https://github.com/yannis/kasaharacup"

RUN apk add --no-cache --update build-base \
  bash \
  git \
  postgresql-dev \
  nodejs \
  npm \
  yarn \
  vips \
  tzdata \
  gcompat \
  graphviz \
  font-noto \
  fontconfig \
  yaml-dev \
  linux-headers \
  && rm -rf /var/cache/apk/*

RUN fc-cache -f

WORKDIR /app

RUN echo 'gem: --no-rdoc --no-ri >> "$HOME/.gemrc"'

ENV PATH="./bin:$PATH"

COPY Gemfile Gemfile.lock package.json yarn.lock ./

RUN gem update --system
RUN bundle config set --local force_ruby_platform true
RUN bundle install -j $(nproc)
RUN npm install -g corepack
RUN corepack enable && yarn install --immutable

ENTRYPOINT ["./docker-entrypoint.sh"]
