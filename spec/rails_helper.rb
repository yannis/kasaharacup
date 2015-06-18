# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require 'rails_helper'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

require "email_spec"
require 'shoulda/matchers'
require 'capybara/rspec'
require 'capybara/rails'
require 'devise'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
  config.include FactoryGirl::Syntax::Methods
  # config.include Paperclip::Shoulda::Matchers
  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  config.mock_framework = :rspec
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true


  config.before(:each) do
    I18n.locale = :en
  end

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!


  def should_be_asked_to_sign_in
    it {expect(response).to redirect_to("http://test.host/users/sign_in?locale=en")}
    it {expect(flash.alert).to eql "You need to sign in or sign up before continuing."}
  end

  def should_not_be_authorized
    it {expect(response.status).to eq 401}
    # it {expect(response.body).to match /You are not authorized to access this page/ }
    it {expect(flash[:alert]).to match /You are not authorized to access this page/ }
  end

  def should_not_find_model
    it {expect(response.status).to eq 422}
    it {expect(response.body).to match /Couldn't find/ }
  end

  def signin(user)
    visit '/users/sign_in'
    if has_selector?("form#new_user[action='/users/sign_in']")
       # current_path == '/users/sign_in'
      fill_in "user_email", :with => user.email
      fill_in "user_password", :with => user.password
      click_button :user_submit
    end
    # page.should have_content('Signed in successfully.')
  end

  # def embersignin(user)
  #   visit "/"
  #   login_as user, scope: :user
  #   page.driver.browser.manage.add_cookie(name: "authToken", value: user.authentication_token)
  #   page.driver.browser.manage.add_cookie(name: "authUserId", value: user.id)
  #   visit "/"
  # end

  # def embersignout
  #   logout :user
  #   Capybara.reset_sessions!
  #   page.driver.browser.manage.delete_cookie(name: "authToken")
  #   page.driver.browser.manage.delete_cookie(name: "authUserId")
  # end

  def flash_is(message)
    within(".notifications") do
      expect(page).to have_text message
    end
  end

  def it_does_not_authorize_and_redirect_to(url)
    within(".notifications") do
      expect(page).to have_text "You are not authorized to access this page"
    end
    expect(current_url).to match url
  end

  def signin_and_visit(user, url)
    login_as user, scope: :user
    visit url
    # visit url
    # if page.has_selector?("form#new_user[action='/users/sign_in']")
    #   fill_in "user_email", :with => user.email
    #   fill_in "user_password", :with => user.password
    #   click_button :user_submit
    #   visit url
    # end
  end

  def flash_should_contain(text)
    page.find("div#flash").should have_content text
  end

  def the_path
    uri = URI.parse(current_url)
    return "#{uri.path}?#{uri.query}"
  end

  def signout
    reset_sessions!
  end

  # def fill_registration_abstract(text)
  #   #js must be enabled
  #   page.execute_script  "bio14.registration.editor.setValue('#{text}')"
  #   # page.execute_script("editor.setValue('#{text}')")
  # end

  def deadline_passed
    it {expect(response).to redirect_to root_path(locale: I18n.locale)}
    it {expect(flash[:alert]).to eq I18n.t("kenshis.deadline_passed", email: 'info@kendo-geneve.ch')}
  end
end
