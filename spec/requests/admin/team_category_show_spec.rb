# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team category show page" do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def category_with_team(**attrs)
    category = create(:team_category, cup: cup, team_size: 3, **attrs)
    create(:team, team_category: category, name: "Kyoto")
    category
  end

  it "shows the seeding panel on a pooled category" do
    category = category_with_team(pool_size: 3)

    get admin_team_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("team_seeds_#{category.id}")
    expect(response.body).to include("Seeding")
  end

  # The individual panel sits behind a pool_size guard because a pool-less
  # individual category has no bracket at all. A bracket-only TEAM category
  # does, and its seeds decide the byes and the protected positions, so the
  # panel has to be reachable there too.
  it "shows the seeding panel on a bracket-only category" do
    category = category_with_team(pool_size: 1)

    get admin_team_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("team_seeds_#{category.id}")
  end

  it "renders no seeding panel before any team is registered" do
    category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)

    get admin_team_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("team_seeds_#{category.id}")
  end

  # The Bracket panel chrome moved out of Arbre into a partial so a freeze
  # broadcast can replace it; the Pools panel gained one it never had. These
  # pin what the move carries.
  describe "panel chrome" do
    it "gives the Pools panel a freeze control once the draw exists" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:team, team_category: category, name: "Kyoto", pool_number: 1)

      get admin_team_category_path(category)

      expect(response.body).to include("team_pools_actions_#{category.id}")
      # The control is asserted by its endpoint, not its label: the admin
      # renders in French and the label is a translation.
      expect(response.body).to include(admin_team_category_pool_freeze_path(category))
    end

    it "keeps the bracket links and adds the freeze control" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:encounter, team_category: category, round: 1, position: 1)

      get admin_team_category_path(category)

      expect(response.body).to include("team_bracket_actions_#{category.id}")
      expect(response.body).to include("Update bracket")
      expect(response.body).to include("Force rebuild")
      expect(response.body).to include("Download PDF")
      expect(response.body).to include(admin_team_category_bracket_freeze_path(category))
    end

    # The two stream-link links point at a POST-only endpoint. Turbo prefetches
    # a plain link on hover, which GETs that endpoint and raises a routing
    # error before the admin has even clicked, so both must opt out.
    it "opts the bracket links out of Turbo's hover prefetch" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:encounter, team_category: category, round: 1, position: 1)

      get admin_team_category_path(category)

      links = response.parsed_body.css("a[data-controller='stream-link']")
      expect(links.size).to eq 2
      expect(links.pluck("data-turbo-prefetch")).to all(eq("false"))
    end

    # bracket_only? drops "Update bracket": there are no standings to fill in.
    it "drops the update link on a bracket-only category" do
      category = create(:team_category, cup: cup, pool_size: 1, team_size: 3)
      create(:encounter, team_category: category, round: 1, position: 1)

      get admin_team_category_path(category)

      expect(response.body).not_to include("Update bracket")
      expect(response.body).to include("Force rebuild")
    end
  end

  # The panel owns the seed order now; a free-text field on the team form could
  # set 7 with no 1..6 and the two paths would disagree about the draw.
  it "offers no seed field on the team form" do
    category = category_with_team(pool_size: 3)

    get edit_admin_team_path(category.teams.first)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("team_seed")
  end

  describe "when frozen" do
    it "drops the pool formation controls and the redraw action item" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:team, team_category: category, name: "Kyoto", pool_number: 1)
      category.freeze_pools!

      get admin_team_category_path(category)

      expect(response.body).not_to include("pool-unpooled__grip")
      expect(response.body).not_to include(generate_pools_admin_team_category_path(category))
      expect(response.body).to include(admin_team_category_pool_freeze_path(category))
    end

    it "drops the bracket rebuild links when the bracket is frozen" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:encounter, team_category: category, round: 1, position: 1)
      category.freeze_bracket!

      get admin_team_category_path(category)

      expect(response.body).not_to include("Update bracket")
      expect(response.body).not_to include("Force rebuild")
      expect(response.body).to include("Download PDF")
    end

    # The page-header action item, which the panel partial does not reach. The
    # endpoint refuses it anyway, so leaving it on the page only offers a
    # control that always fails.
    it "drops the Generate bracket action item when the bracket is frozen" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:encounter, team_category: category, round: 1, position: 1)

      get admin_team_category_path(category)
      expect(response.body).to include(generate_bracket_admin_team_category_path(category))

      category.freeze_bracket!
      get admin_team_category_path(category)

      expect(response.body).not_to include(generate_bracket_admin_team_category_path(category))
    end

    # freezable? reads live state and the freeze endpoints do not require it,
    # so a surface can be frozen and then stop being freezable. Gating the
    # whole control on freezable? alone stranded such a category read-only with
    # no unfreeze button on its own page.
    it "keeps the unfreeze control on a frozen category that is no longer freezable" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:team, team_category: category, name: "Kyoto", pool_number: 1)
      category.freeze_pools!
      # delete_all, the way a cascade reaches these rows: the model guard
      # exempts that path, which is how a frozen category loses its draw.
      category.teams.delete_all

      get admin_team_category_path(category)

      expect(category.reload).to be_pools_frozen
      expect(category).not_to be_pools_freezable
      expect(response.body).to include(admin_team_category_pool_freeze_path(category))
    end
  end

  # The state the organizers actually reorder in, end to end: pools drawn, the
  # bracket built from their descriptors, and nobody resolved into a slot yet.
  # Every unit test covers a piece of this; nothing else covers the page.
  describe "a pooled bracket whose pools have not finished" do
    let(:category) { create(:team_category, cup: cup, team_size: 3, pool_size: 3, out_of_pool: 2) }

    before do
      (1..2).each do |pool|
        (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(category).call
      # Un-resolve every slot: the labels stay, the teams go.
      category.bracket_encounters.where(round: 1).find_each do |encounter|
        encounter.update_columns(team_1_id: nil, team_2_id: nil) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    it "renders the tree with every slot reorderable, and the waiting panel" do
      get admin_team_category_path(category)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include "competition-tree__grip"
      expect(response.body).to include "competition-tree__move-select"
      expect(response.body).to include BracketWaitingComponent.dom_id_for(category)
      # Nothing was pulled out, so the area is empty and says so.
      expect(response.body).to include "Drag an entry here"
    end

    it "wraps the tree and the waiting panel in one bracket-slot controller" do
      get admin_team_category_path(category)

      expect(response.body.scan('data-controller="bracket-slot"').size).to eq 1
    end
  end
end
