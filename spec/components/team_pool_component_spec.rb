# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPoolComponent, type: :component do
  it "renders a standings row per team with the pool number" do
    tc = create(:team_category, pool_size: 3)
    t1 = create(:team, team_category: tc, pool_number: 1, pool_position: 1)
    t2 = create(:team, team_category: tc, pool_number: 1, pool_position: 2)

    render_inline(described_class.new(team_category: tc, pool_number: 1, admin: false))

    expect(page).to have_text("Pool 1")
    expect(page).to have_text(t1.name)
    expect(page).to have_text(t2.name)
  end
end
