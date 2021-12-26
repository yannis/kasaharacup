# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.0.3"

gem "rails", "~> 7.0.0"

# Database
gem "pg", "~> 1.1"

# Server
gem "puma", "~> 5.0"

# Authentication and Authorization
gem "devise"
gem "cancancan"

# Front stuff
gem "cssbundling-rails"
gem "jsbundling-rails"
gem "sass-rails"
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# PDF generation
gem "prawn"

# Misc
gem "bootsnap", require: false
gem "rack-cors"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# activeadmin
gem "activeadmin", github: "tagliala/activeadmin", branch: "feature/railties-7" # FIXME: revert to stable
gem "arbre", github: "activeadmin/arbre" # FIXME: remove
gem "inherited_resources", github: "activeadmin/inherited_resources" # FIXME: remove
gem "kaminari", github: "kaminari/kaminari" # FIXME: remove
gem "ransack", github: "activerecord-hackery/ransack" # FIXME: remove

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "rspec-rails", "~> 5.0.0"
  gem "rubocop-rails_config", require: false
  gem "rubocop-rspec", require: false
  gem "standard"
end

group :development do
  gem "brakeman"
  # gem "i18n-tasks" => Temporary deactivated, see https://github.com/digitalepidemiologylab/myfoodrepo/issues/113
  gem "letter_opener_web", "~> 2.0"
  gem "solargraph"
  gem "rack-mini-profiler"
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
  gem "webdrivers"
end
