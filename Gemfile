# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.0"

gem "rails", "~> 8.1.1"

# Database
gem "pg"

# Server
gem "puma"

# Authentication and Authorization
gem "devise"
gem "cancancan"

# Front stuff
gem "cssbundling-rails"
gem "jsbundling-rails"
gem "sassc-rails"
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.0"

# reCAPTCHA
gem "recaptcha"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# PDF generation
gem "prawn"
gem "prawn-table"

# Misc
gem "bootsnap", require: false
gem "rack-cors"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# activeadmin
gem "activeadmin"

# ActiveStorage and Image processing
gem "aws-sdk-s3"
gem "image_processing"

# ViewComponent
gem "view_component"
gem "lookbook" # Need to be after the `view_component` gem

# Countries
gem "countries"
gem "country_select"

# Edit in place
gem "best_in_place", git: "https://github.com/mmotherwell/best_in_place"

# Exceptions notification
gem "honeybadger"

# HTTP requests
gem "httparty"

# Markdown
gem "kramdown"

# Required for Ruby 3.1
gem "matrix"

group :development, :test do
  gem "debug", platforms: %i[mri windows]
  gem "dotenv-rails"
  gem "erb_lint"
  gem "factory_bot_rails"
  gem "faker"
  gem "libyear-bundler"
  gem "parallel_tests"
  gem "rspec-rails"
  gem "rubocop-rails_config", require: false
  gem "rubocop-rspec", require: false
  gem "standard"
end

group :development do
  gem "active_record_doctor"
  gem "brakeman"
  gem "i18n-tasks"
  gem "letter_opener_web"
  gem "pg_query"
  gem "prosopite"
  gem "solargraph"
  gem "rack-mini-profiler"
  gem "ruby-lsp"
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "rails-controller-testing"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "webmock"
end
