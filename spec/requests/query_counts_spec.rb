# frozen_string_literal: true

require "rails_helper"

# An N+1 is a query count that grows with the number of rows on the page. Every
# page here is rendered twice — once over a small cup, once after the same cup
# has grown — and asked to send the database exactly as many queries the second
# time. Counting queries against a fixed number would only measure today's
# implementation; comparing two sizes measures the thing that actually hurts.
RSpec.describe "Query counts" do
  let(:cup) { create(:cup, :with_cup_products) }
  let(:individual_category) { create(:individual_category, cup: cup, pool_size: 3) }
  let(:team_category) { create(:team_category, cup: cup, team_size: 3, pool_size: 2, out_of_pool: 1) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  # One more club, one more individual pool, one more team of three, one more
  # ronin and one more shinpan: every collection the pages below iterate over
  # gets longer.
  def register_a_batch
    team = create(:team, team_category: team_category)
    pool_number = (individual_category.participations.maximum(:pool_number) || 0) + 1
    3.times do
      kenshi = create(:kenshi, cup: cup, user: user, club: create(:club))
      create(:participation, category: individual_category, kenshi: kenshi, pool_number: pool_number)
      create(:participation, category: team_category, kenshi: kenshi, team: team)
      create(:purchase, kenshi: kenshi, product: cup.product_individual_adult)
    end
    ronin = create(:kenshi, cup: cup, user: user, club: create(:club))
    create(:participation, category: team_category, kenshi: ronin, ronin: true)
    create(:kenshi, cup: cup, user: user, club: create(:club), shinpan: true)
    team
  end

  # One more pool of two fully rostered teams, and the pool encounter between
  # them: the admin category page grows by a pool card.
  def add_a_pool
    number = team_category.teams.maximum(:pool_number).to_i + 1
    2.times do |rank|
      team = create(:team, team_category: team_category, pool_number: number, pool_rank: rank + 1)
      3.times do
        kenshi = create(:kenshi, cup: cup, user: user, club: create(:club))
        create(:participation, category: team_category, kenshi: kenshi, team: team)
      end
    end
    PoolEncounterGenerator.new(team_category).call
  end

  # A pool, plus the elimination bracket redrawn over the new standings: the
  # encounter list names an unresolved bracket slot through its parent, so the
  # bracket is what puts that path under measurement.
  def add_a_pool_and_redraw_the_bracket
    add_a_pool
    TeamCategoryBracketBuilder.new(team_category.reload, rebuild_started: true).call
  end

  def queries_for(path)
    get path
    expect(response).to have_http_status(:ok)
    count_queries { get path }
  end

  RSpec.shared_examples "a page whose query count does not grow" do
    let(:grow) { -> { register_a_batch } }

    # Two batches before the first reading, four before the second. Starting at
    # one of everything would measure the wrong thing: with a single row per
    # collection, several preloads issue byte-identical SQL and Rails' per-request
    # query cache serves all but the first, so the baseline reads artificially low.
    it "sends the same queries over a cup twice the size" do
      2.times { grow.call }
      small = queries_for(path)
      2.times { grow.call }
      large = queries_for(path)

      expect(large).to send_no_more_queries_than(small)
    end
  end

  context "when signed in as the registering user" do
    before { sign_in user }

    context "with the cup home page" do
      let(:path) { cup_path(cup) }

      it_behaves_like "a page whose query count does not grow"
    end

    context "with the user's own registrations" do
      let(:path) { cup_user_path(cup) }

      it_behaves_like "a page whose query count does not grow"
    end

    context "with the kenshi list" do
      let(:path) { cup_kenshis_path(cup) }

      it_behaves_like "a page whose query count does not grow"
    end

    context "with the team list" do
      let(:path) { cup_teams_path(cup) }

      it_behaves_like "a page whose query count does not grow"
    end
  end

  context "when signed in as an admin" do
    before { sign_in admin }

    context "with the ActiveAdmin kenshi list" do
      let(:path) { admin_kenshis_path }

      it_behaves_like "a page whose query count does not grow"
    end

    context "with the ActiveAdmin team list" do
      let(:path) { admin_teams_path }

      it_behaves_like "a page whose query count does not grow"
    end

    context "with the team category pools" do
      let(:path) { admin_team_category_path(team_category) }

      it_behaves_like "a page whose query count does not grow" do
        let(:grow) { -> { add_a_pool } }
      end
    end

    context "with the encounter list" do
      let(:path) { admin_team_category_encounters_path(team_category) }

      it_behaves_like "a page whose query count does not grow" do
        let(:grow) { -> { add_a_pool_and_redraw_the_bracket } }
      end
    end
  end

  # The printed material is where a namesake lookup per fighter hurts most: a
  # category PDF is generated for every category, on the morning of the cup.
  context "when an admin prints" do
    before { sign_in admin }

    context "the individual category recap" do
      let(:path) { pdf_recap_admin_individual_category_path(individual_category) }

      it_behaves_like "a page whose query count does not grow"
    end

    context "the individual pool match sheets" do
      let(:path) { pool_sheets_admin_individual_category_path(individual_category) }

      it_behaves_like "a page whose query count does not grow"
    end

    context "the team category boards" do
      let(:path) { pdf_admin_team_category_path(team_category) }

      it_behaves_like "a page whose query count does not grow"
    end

    context "every kenshi's board" do
      let(:path) { pdfs_admin_kenshis_path }

      it_behaves_like "a page whose query count does not grow"
    end
  end
end
