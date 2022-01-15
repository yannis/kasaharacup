# frozen_string_literal: true

RSpec.configure do |config|
  def should_be_asked_to_sign_in
    expect(response).to redirect_to(new_user_session_path)
    expect(flash.alert).to eql "You need to sign in or sign up before continuing."
  end

  def should_not_be_authorized
    expect(response.status).to eq 401
    expect(flash[:alert]).to match /You are not authorized to access this page/
  end

  def should_not_find_model
    it { expect(response.status).to eq 422 }
    it { expect(response.body).to match /Couldn't find/ }
  end

  def signin(user)
    visit "/users/sign_in"
    if has_selector?("form#new_user[action='/users/sign_in']")
      # current_path == '/users/sign_in'
      fill_in "user_email", with: user.email
      fill_in "user_password", with: user.password
      click_button :user_submit
    end
    # page.should have_content('Logged in successfully.')
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
    "#{uri.path}?#{uri.query}"
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
    it { expect(response).to redirect_to root_path(locale: I18n.locale) }
    it { expect(flash[:alert]).to eq I18n.t("kenshis.deadline_passed", email: "info@kendo-geneve.ch") }
  end
end
