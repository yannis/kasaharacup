# frozen_string_literal: true

RSpec.configure do |config|
  def should_be_asked_to_sign_in
    expect(response).to redirect_to(new_user_session_path)
    expect(flash.alert).to eql "Vous devez vous connecter ou vous inscrire pour continuer."
  end

  def should_not_be_authorized
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to match(/You are not authorized to access this page/)
  end

  def should_not_find_model
    it { expect(response).to have_http_status :unprocessable_content }
    it { expect(response.body).to match(/Couldn't find/) }
  end

  def signin(user)
    visit "/users/sign_in"
    if has_selector?("form#new_user[action='/users/sign_in']")
      # current_path == '/users/sign_in'
      fill_in "user_email", with: user.email
      fill_in "user_password", with: user.password
      click_on(:user_submit)
    end
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

  def has_passed_deadline
    expect(response).to redirect_to root_path(locale: I18n.locale)
    expect(flash[:alert]).to eq I18n.t("kenshis.deadline_passed", email: ENV.fetch("CONTACT_EMAIL"))
  end
end
