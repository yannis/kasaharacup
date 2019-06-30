source 'https://rubygems.org'
ruby "2.3.3"

# Bundle edge Rails instead: gem 'rails', git: 'https://github.com/rails/rails'
gem 'rails', '4.2.11.1'
# Use postgresql as the database for Active Record
gem 'pg', '0.20'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
gem "coffee-rails"
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

gem "devise", ">= 4.6.0"
gem "cancancan"

# gem 'omniauth-twitter'
gem 'omniauth-facebook'
# gem 'omniauth-github'
# gem 'omniauth-google'

# Use jquery as the JavaScript library
gem 'jquery-rails'
gem "jquery-ui-rails"
gem "select2-rails", "3.5.10"
gem "bootstrap3-datetimepicker-rails"
gem "font-awesome-sass"
gem 'compass-rails', git: "https://github.com/Compass/compass-rails"
gem "pkg-config", "~> 1.1"

# gem "asset_sync"
gem 'gibbon'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
# gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# gem "kendocup", path: "/Users/yannis/railsapps/kendocup"
gem "kendocup", git: "https://github.com/yannis/kendocup"

gem 'bootstrap-sass', '~> 3.4.1'

gem 'simple_form'

gem 'best_in_place', git: 'https://github.com/bernat/best_in_place'

gem 'seed_dump'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem "quiet_assets"
end

group :developement do
  gem "guard"
  gem "guard-rspec"
  gem "guard-bundler"
  gem "guard-livereload"
  # gem "guard-spring"
  gem "rspec-rails"
  gem "rspec-mocks"
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'
end

group :test do
  gem "faker"
  gem 'timecop'
  gem 'email_spec'
  gem "factory_girl_rails"
  gem "selenium-webdriver"
  gem "capybara-webkit"
  # gem "minitest" # temporary fix for https://github.com/thoughtbot/shoulda-matchers/issues/408
  gem 'shoulda-matchers', require: false
end

group :production do |variable|
  gem 'unicorn'
  gem 'rails_12factor'
end
