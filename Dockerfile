FROM ruby:3.3.1-alpine
LABEL mainainer="yannisjaquet@mac.com"
LABEL org.opencontainers.image.source="https://github.com/yannis/kasaharacup"

RUN apk add --no-cache --update build-base \
  bash \
  git \
  postgresql-dev \
  nodejs \
  yarn \
  vips \
  tzdata \
  gcompat \
  graphviz \
  font-noto \
  fontconfig \
  && rm -rf /var/cache/apk/*

RUN fc-cache -f

WORKDIR /app

RUN echo 'gem: --no-rdoc --no-ri >> "$HOME/.gemrc"'

ENV PATH ./bin:$PATH

COPY Gemfile Gemfile.lock package.json yarn.lock ./

RUN gem update --system
RUN bundle config set --local force_ruby_platform true
RUN bundle install -j $(nproc)
RUN yarn install --frozen-lockfile --non-interactive

ENTRYPOINT ["./docker-entrypoint.sh"]
