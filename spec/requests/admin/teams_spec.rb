# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin teams" do
  let(:cup) { create(:cup) }
  let(:team_category) { create(:team_category, cup: cup) }
  let(:team) { create(:team, name: "Swiss Team", team_category: team_category) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "reports a validation failure instead of answering 200 and losing the edit" do
    patch admin_team_path(team), params: {team: {name: ""}}, as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
    expect(team.reload.name).to eq "Swiss Team"
  end
end
