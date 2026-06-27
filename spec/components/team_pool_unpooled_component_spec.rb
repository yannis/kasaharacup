# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPoolUnpooledComponent, type: :component do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, pool_size: 3) }

  it "lists only unpooled teams, draggable, with an add-to select" do
    create(:team, team_category: tc, pool_number: 1, pool_position: 1)
    create(:team, team_category: tc, pool_number: 1, pool_position: 2)
    late = create(:team, team_category: tc, pool_number: nil)

    render_inline(described_class.new(team_category: tc))

    expect(page).to have_text("Unpooled teams")
    expect(page).to have_css("li.pool-unpooled__team[data-team-id='#{late.id}']")
    expect(page).to have_css("li[data-team-id='#{late.id}'] .pool-unpooled__grip[draggable='true']")
    expect(page).to have_text(late.name)
  end

  it "offers each existing pool plus a New pool option in the select" do
    create(:team, team_category: tc, pool_number: 1, pool_position: 1)
    create(:team, team_category: tc, pool_number: 2, pool_position: 1)
    create(:team, team_category: tc, pool_number: nil)

    render_inline(described_class.new(team_category: tc))

    expect(page).to have_css("option[value='1']", text: "Pool 1")
    expect(page).to have_css("option[value='2']", text: "Pool 2")
    expect(page).to have_css("option[value='3']", text: "New pool (Pool 3)") # max(2) + 1
  end

  it "stays visible as a drop zone even when no teams are unpooled" do
    create(:team, team_category: tc, pool_number: 1, pool_position: 1)

    render_inline(described_class.new(team_category: tc))

    expect(page).to have_css("#team_pool_unpooled_#{tc.id}.pool-unpooled")
    expect(page).to have_text("Unpooled teams")
    expect(page).to have_text("Drag a team here to remove it from its pool.")
    expect(page).to have_css("[data-action*='drop->pool-membership#dropUnpool']")
  end
end
