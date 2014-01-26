source 'https://rubygems.org'
ruby '2.0.0'

gem 'rails', '4.0.2'
gem 'pg'
gem 'jquery-rails'
gem 'haml-rails'
gem "jquery-ui-rails"
gem 'newrelic_rpm'

gem "devise"
gem "cancan", "1.6.10"
gem 'html5-rails'
gem 'omniauth-facebook'
gem 'csv_builder'
gem 'gibbon'
gem 'rails3-jquery-autocomplete'
gem 'airbrake'
gem 'figaro'
gem "asset_sync"
gem 'prawn'
# For spambots
gem "honeypot-captcha"
gem 'activeadmin', github: 'gregbell/active_admin'
gem 'foundation-rails'

# group :assets do
gem 'sass-rails'
gem 'compass-rails'
gem 'compass-h5bp'
gem 'coffee-rails'
gem 'uglifier'
gem 'font-awesome-rails'
# end

group :test do
  gem "factory_girl_rails"
  gem "rspec-rails"
  gem "rspec-instafail"
  gem 'email_spec'
  gem 'shoulda-matchers'
  gem 'capybara-screenshot', :require => false
  # gem 'simplecov', :require => false
end

group :development, :test do
  gem 'rb-inotify', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-fchange', require: false
  gem "database_cleaner"
  gem "guard"
  gem 'guard-rails-assets'
  gem "guard-sprockets"
  # gem "guard-test"
  gem "guard-bundler"
  gem "guard-livereload"
  gem 'guard-rspec'
  gem 'guard-zeus'
  gem "launchy"
  gem "capybara"
  gem "selenium-webdriver"
  gem "timecop"
end
group :production, :staging do
  gem 'unicorn'
  gem 'rails_12factor'
end
