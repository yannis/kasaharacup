# frozen_string_literal: true

require "rails_helper"

# A browser decides what it has been handed from the content type and the
# filename. Sent without an extension, every one of these arrives as a nameless
# blob the operating system will not open on a double-click.
RSpec.describe "PDF downloads" do
  let(:cup) { create(:cup, :with_cup_products) }
  let(:admin) { create(:user, :admin) }
  let(:individual_category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 1) }
  let(:team_category) { create(:team_category, cup: cup, team_size: 3, pool_size: 2, out_of_pool: 1) }
  let(:team) { team_category.teams.first }
  let(:kenshi) { cup.kenshis.first }

  before do
    cup.update!(end_on: cup.start_on + 1.day)
    2.times do |pool|
      3.times do |index|
        fighter = create(:kenshi, cup: cup)
        create(:participation, category: individual_category, kenshi: fighter,
          pool_number: pool + 1, pool_position: index + 1, pool_rank: index + 1)
      end
      2.times do |index|
        pool_team = create(:team, team_category: team_category,
          pool_number: pool + 1, pool_position: index + 1, pool_rank: index + 1)
        3.times { create(:participation, category: team_category, kenshi: create(:kenshi, cup: cup), team: pool_team) }
      end
    end
    PoolFightGenerator.new(individual_category).call
    PoolEncounterGenerator.new(team_category).call
    IndividualCategoryBracketBuilder.new(individual_category).call
    TeamCategoryBracketBuilder.new(team_category).call
    sign_in admin
  end

  def sent_filename
    response.headers["Content-Disposition"][/filename="?([^";]+)"?/, 1]
  end

  # Five documents about one category used to arrive under its bare name, so
  # saving them all left one file and four copies of it.
  it "gives each of a category's documents a filename of its own" do
    individual = %w[pdf pdf_recap sheet pool_sheets competition_tree_pdf].map do |action|
      get "/admin/individual_categories/#{individual_category.id}/#{action}"
      sent_filename
    end
    team = %w[pdf team_match_sheet pool_sheets bracket_pdf].map do |action|
      get "/admin/team_categories/#{team_category.id}/#{action}"
      sent_filename
    end

    expect(individual).to all(end_with(".pdf"))
    expect(individual.uniq.size).to eq(individual.size), "duplicates among #{individual.inspect}"
    expect(team.uniq.size).to eq(team.size), "duplicates among #{team.inspect}"
  end

  {
    "a kenshi's board" => ->(c) { "/admin/kenshis/#{c[:kenshi].id}/pdf" },
    "every kenshi's board" => ->(_c) { "/admin/kenshis/pdfs" },
    "a team's boards" => ->(c) { "/admin/teams/#{c[:team].id}/pdf" },
    "an individual category's boards" => ->(c) { "/admin/individual_categories/#{c[:individual].id}/pdf" },
    "an individual category's recap" => ->(c) { "/admin/individual_categories/#{c[:individual].id}/pdf_recap" },
    "an individual category's match sheet" => ->(c) { "/admin/individual_categories/#{c[:individual].id}/sheet" },
    "an individual category's pool sheets" => ->(c) { "/admin/individual_categories/#{c[:individual].id}/pool_sheets" },
    "an individual category's tree" =>
      ->(c) { "/admin/individual_categories/#{c[:individual].id}/competition_tree_pdf" },
    "a team category's boards" => ->(c) { "/admin/team_categories/#{c[:team_category].id}/pdf" },
    "a team category's match sheet" => ->(c) { "/admin/team_categories/#{c[:team_category].id}/team_match_sheet" },
    "a team category's pool sheets" => ->(c) { "/admin/team_categories/#{c[:team_category].id}/pool_sheets" },
    "a team category's bracket" => ->(c) { "/admin/team_categories/#{c[:team_category].id}/bracket_pdf" },
    "the junior waiver" => ->(c) { "/en/cups/#{c[:cup].year}/waiver" }
  }.each do |what, path|
    it "sends #{what} as a named PDF" do
      get path.call(cup: cup, kenshi: kenshi, team: team,
        individual: individual_category, team_category: team_category)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/pdf"
      expect(response.body).to start_with("%PDF")
      expect(sent_filename).to end_with(".pdf")
    end
  end
end
