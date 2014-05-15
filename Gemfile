source 'https://rubygems.org'
ruby "2.0.0"

gem 'rails', '4.1.0'
gem 'pg'
gem 'bundler'
gem 'htmlentities'
gem "actionview-encoded_mail_to"
gem "active_model_serializers"
gem "devise"
gem "cancancan"
# gem "omniauth"
gem 'omniauth-twitter'
gem 'omniauth-facebook'
gem 'omniauth-github'
gem 'omniauth-google'
gem 'uglifier', '>= 1.3.0'
gem 'rails3-jquery-autocomplete', '~> 1.0.14'
gem "figaro", github: "laserlemon/figaro"
gem "asset_sync"

gem 'activeadmin', github: 'gregbell/active_admin'
gem 'polyamorous', github: 'activerecord-hackery/polyamorous'
gem 'ransack',     github: 'activerecord-hackery/ransack'
gem 'formtastic',  github: 'justinfrench/formtastic'

gem 'sass-rails', '~> 4.0'
gem 'coffee-rails'
gem 'haml-rails'
gem 'html5-rails'
gem 'jquery-rails'
gem "jquery-ui-rails"
gem "calendar_date_select"
gem 'bootstrap3-datetimepicker-rails', '~> 3.0.0'
gem "font-awesome-sass"
gem "bootstrap-sass", git: "git://github.com/twbs/bootstrap-sass"
gem "calendar_helper"
gem 'momentjs-rails', '~> 2.5.0'
gem 'compass-rails'
gem "select2-rails"

gem 'airbrake'
gem "newrelic_rpm"

group :development do
  gem "spring"
  gem 'spring-commands-rspec'
  gem "capistrano"
  gem 'capistrano-rails', '~> 1.1'
  gem 'capistrano-bundler'
  gem 'capistrano-rbenv', '~> 2.0'
  gem "guard-livereload"
  gem 'guard-spring'
  gem 'guard-rspec', require: false
  gem 'guard-bundler'
  gem 'rb-inotify', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-fchange', require: false
  gem 'quiet_assets'
  # gem "better_errors"
  gem "binding_of_caller"
  gem "rspec-rails"
  gem "rails_best_practices"
  gem "brakeman", :require => false
  # gem "debugger"
  gem "bullet"
end

group :test do
  gem "rspec-instafail"
  gem "launchy"
  gem "database_cleaner"
  gem "faker"
  gem 'timecop'
  gem 'email_spec'
  gem "factory_girl_rails"
  gem "selenium-webdriver"
  gem "capybara-webkit"
  gem "minitest" # temporary fix for https://github.com/thoughtbot/shoulda-matchers/issues/408
  gem 'shoulda-matchers'
  gem 'capybara-screenshot', git: "git://github.com/mattheworiordan/capybara-screenshot.git"
  gem 'simplecov', :require => false
end

group :production do
  gem "rails_12factor"
  gem "unicorn"
end
