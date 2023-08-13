# frozen_string_literal: true

require "rails_helper"

describe("Show/hide additional info form", :js) do
  let(:email) { "user@kasaharacup.com" }
  let(:password) { "password" }
  let!(:cup) { create(:cup) }
  let!(:user) { create(:user, email: email, password: password) }
  let!(:kenshi) { create(:kenshi, cup: cup, user: user) }
  let!(:product) { create(:product, cup: cup, require_personal_infos: true) }

  it do
    if !ENV["SYSTEM_SPECS"]
      skip("Unable to have Selenium run on Docker")
    end
    signin_and_visit(user, cup_user_path(cup))
    expect(page).to have_content("#{kenshi.first_name} #{kenshi.last_name}")
    within("ul[role=list] li") do
      click_link("Modifier")
    end
    expect(page).to have_current_path(edit_cup_kenshi_path(cup, kenshi))
    expect(page).to have_content("Modifiez l'inscription de #{kenshi.first_name} #{kenshi.last_name}")
  end
end
