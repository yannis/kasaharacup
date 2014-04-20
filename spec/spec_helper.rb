if ENV['COV']
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter "/rails/"
  end
end
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require "email_spec"
require 'capybara/rspec'
require 'capybara/rails'
require 'capybara-screenshot/rspec'
# require "paperclip/matchers"

Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  # config.include Paperclip::Shoulda::Matchers
  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  # config.include Warden::Test::Helpers
  # Warden.test_mode!


# DesiredCapabilities capabilities = DesiredCapabilities.Chrome();
# capabilities.SetCapability("chrome.switches", new List<String>() {
#     "--start-maximized",
#     "--disable-popup-blocking" });
# driver = new OpenQA.Selenium.Chrome.ChromeDriver(capabilities);


  Capybara.register_driver :chrome do |app|
    caps = Selenium::WebDriver::Remote::Capabilities.chrome(chromeOptions: {args: [ "--start-maximized" ]})
    driver = Capybara::Selenium::Driver.new(app, {browser: :chrome, desired_capabilities: caps})
    # driver.window_maximize
    # driver
  end


  Capybara::Screenshot.register_driver(:chrome) do |driver, path|
   driver.save_screenshot(path)
 end

  Capybara.javascript_driver = :chrome
  Capybara.save_and_open_page_path = "/tmp/capybara"

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  # config.all_on_start false
  config.order = 'random'
  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    # system("rm -rf #{Rails.root.join("tmp/capybara/*")}")
  end

  config.before(:each) do
    if example.metadata[:js]
      page.driver.browser.manage.window.resize_to(1366,768)
    end
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # config.before(:each) { GC.disable }
  # config.after(:each) { GC.enable }
  # config.before(:all) { DeferredGarbageCollection.start }
  # config.after(:all) { DeferredGarbageCollection.reconsider }

  def should_be_asked_to_sign_in
    it {response.should redirect_to(new_user_session_path)}
    it {flash[:alert].should =~ /Please sign in/}
  end

  def should_not_be_authorized
    it {expect(response.status).to eq 401}
    it {expect(response.body).to match /You are not authorized to access this page/ }
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

  def embersignin(user)
    visit "/"
    login_as user, scope: :user
    page.driver.browser.manage.add_cookie(name: "authToken", value: user.authentication_token)
    page.driver.browser.manage.add_cookie(name: "authUserId", value: user.id)
    visit "/"
  end

  def embersignout
    logout :user
    Capybara.reset_sessions!
    page.driver.browser.manage.delete_cookie(name: "authToken")
    page.driver.browser.manage.delete_cookie(name: "authUserId")
  end

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

  def drag_to(source, target)
    builder = page.driver.browser.action
    source = source.native
    target = target.native

    builder.click_and_hold source
    builder.move_to        target, 1, 11
    builder.move_to        target
    builder.release        target
    builder.perform
  end
end
