# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterTreeComponent, type: :component do
  let(:tc) { create(:team_category, pool_size: 3, out_of_pool: 1) }

  def ranked_team(pool_number)
    create(:team, team_category: tc, pool_number: pool_number, pool_rank: 1)
  end

  it "renders a card per resolved round-1 encounter with team names" do
    a = ranked_team(1)
    b = ranked_team(2)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    expect(page).to have_text(a.name)
    expect(page).to have_text(b.name)
    # The link targets the encounter panel frame below the tree (no _top) so the
    # editor opens beneath the bracket; the encounter show renders that frame.
    expect(page).to have_link("Encounter 1")
    expect(page).to have_no_css('a[data-turbo-frame="_top"]')
  end

  it "targets the encounter panel frame so the bracket stays visible on click" do
    ranked_team(1)
    ranked_team(2)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    expect(page).to have_css(
      %(a[data-turbo-frame="encounter_panel_team_category_#{tc.id}"]),
      text: "Encounter 1"
    )
  end

  it "shows a 'Waiting for encounter N' placeholder for an unresolved round-2 slot" do
    ranked_team(1)
    ranked_team(2)
    ranked_team(3)
    ranked_team(4)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    # The final's slots forecast their undecided round-1 parents (mirrors the
    # individual tree's "Waiting for fight N").
    expect(page).to have_text("Waiting for encounter")
  end

  it "renders nothing meaningful when there is no bracket" do
    render_inline(described_class.new(team_category: tc, admin: true))
    expect(page).to have_css(".competition-tree")
  end

  it "ignores an ad-hoc encounter that has no round (does not crash on layout)" do
    a = create(:team, team_category: tc)
    b = create(:team, team_category: tc)
    create(:encounter, team_category: tc, team_1: a, team_2: b) # pool_number nil, round nil

    expect {
      render_inline(described_class.new(team_category: tc, admin: true))
    }.not_to raise_error
    expect(page).to have_text("No bracket yet")
  end

  it "shows a seeded round-1 slot's label once when its team is unresolved" do
    # out_of_pool 2 but only rank-1 teams exist, so the rank-2 slots carry a seed
    # (pool.rank) with no resolved team — the label must render once (prefix), not
    # be duplicated as the slot name.
    tc.update!(out_of_pool: 2)
    create(:team, team_category: tc, pool_number: 1, pool_rank: 1)
    create(:team, team_category: tc, pool_number: 2, pool_rank: 1)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    # Asserted on the prefix ELEMENTS rather than on the page text: the
    # "Move to…" options name every destination by its entry, so "1.2" now
    # legitimately appears in the page several times over. What must not happen
    # is the seed being drawn twice on the card — once as the prefix and again
    # as the slot's name.
    prefixes = page.all(".competition-tree__pool-position").map(&:text)
    expect(prefixes.count("1.2")).to eq 1
    expect(prefixes.count("2.2")).to eq 1
    # The rank-1 slots DO resolve to a team; what must stay empty is the name of
    # a slot whose seed has nobody behind it yet.
    expect(page.all(".competition-tree__fighter-name").map(&:text))
      .not_to include("1.2", "2.2")
  end

  describe "drag-to-swap eligibility" do
    let(:bracket_only) { create(:team_category, pool_size: nil) }

    def build_bracket(team_count = 4)
      create_list(:team, team_count, team_category: bracket_only)
      TeamCategoryBracketBuilder.new(bracket_only, random: Random.new(1)).call
    end

    def round_one
      bracket_only.bracket_encounters.where(round: 1).order(:position).to_a
    end

    it "marks an unscored round-1 slot a source and a target for an admin" do
      build_bracket
      component = described_class.new(team_category: bracket_only, admin: true)

      expect(component.slot_source?(round_one.first, 1)).to be true
      expect(component.slot_target?(round_one.first, 1)).to be true
    end

    it "marks nothing movable for a non-admin" do
      build_bracket
      component = described_class.new(team_category: bracket_only, admin: false)

      expect(component.slot_source?(round_one.first, 1)).to be false
      expect(component.slot_target?(round_one.first, 1)).to be false
    end

    it "renders a grip on both slots of an unscored encounter" do
      build_bracket
      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__grip", count: 4)
    end

    it "renders a grip on a bye card" do
      build_bracket(3)
      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__match--bye .competition-tree__grip")
    end

    it "renders no grip for an encounter with a recorded result" do
      build_bracket
      first = round_one.first
      first.update!(winner: first.team_1)

      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__grip", count: 2)
    end

    it "still renders grips once the lineups have been auto-seeded" do
      build_bracket
      round_one.first.update!(lineup_1_set: true, lineup_2_set: true)

      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__grip", count: 4)
    end

    it "renders no grip for a non-admin" do
      build_bracket
      render_inline(described_class.new(team_category: bracket_only, admin: false))

      expect(page).to have_no_css(".competition-tree__grip")
    end

    it "carries the move payload on a movable slot" do
      build_bracket
      first = round_one.first
      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(
        %([data-slot-id="#{first.id}-1"][data-entry-key="team-#{first.team_1_id}"])
      )
    end

    # The behaviour this whole feature exists to change. A pooled slot used to
    # be refused outright, because a swap wrote the team id and left the pool
    # descriptor behind for the next build to re-resolve.
    it "marks a POOLED round-1 slot movable" do
      ranked_team(1)
      ranked_team(2)
      TeamCategoryBracketBuilder.new(tc).call
      component = described_class.new(team_category: tc, admin: true)
      encounter = tc.bracket_encounters.find_by(round: 1)

      expect(component.slot_source?(encounter, 1)).to be true
    end
  end

  describe "the seed badge" do
    it "badges a seeded team in the tree" do
      a = ranked_team(1)
      a.update!(seed: 1)
      ranked_team(2)
      TeamCategoryBracketBuilder.new(tc).call

      render_inline(described_class.new(team_category: tc, admin: true))

      expect(page).to have_css(".competition-tree__seed", text: "S1")
    end

    # Admin only, like CompetitionTreeComponent's: the seeding is the
    # organizers' reading of the field, not a result.
    it "keeps the badge off a non-admin render" do
      a = ranked_team(1)
      a.update!(seed: 1)
      ranked_team(2)
      TeamCategoryBracketBuilder.new(tc).call

      render_inline(described_class.new(team_category: tc, admin: false))

      expect(page).to have_no_css(".competition-tree__seed")
    end

    it "badges nobody when no one is seeded" do
      ranked_team(1)
      ranked_team(2)
      TeamCategoryBracketBuilder.new(tc).call

      render_inline(described_class.new(team_category: tc, admin: true))

      expect(page).to have_no_css(".competition-tree__seed")
    end

    # The pool-position prefix only shows for a slot no team has reached yet and
    # the badge only for one that has, so a resolved slot never wears both.
    it "does not double up with the pool-position prefix" do
      a = ranked_team(1)
      a.update!(seed: 1)
      ranked_team(2)
      TeamCategoryBracketBuilder.new(tc).call

      render_inline(described_class.new(team_category: tc, admin: true))

      badged = page.find(".competition-tree__seed").find(:xpath, "..")
      expect(badged).to have_no_css(".competition-tree__pool-position")
    end
  end

  # R3: a swap is a draw correction, and a frozen tree refuses it. Reuses the
  # bracket-only setup above, since that is the only shape a swap applies to.
  describe "when the bracket is frozen" do
    let(:frozen_only) { create(:team_category, pool_size: nil) }

    before do
      create_list(:team, 4, team_category: frozen_only)
      TeamCategoryBracketBuilder.new(frozen_only, random: Random.new(1)).call
    end

    def round_one_slot
      frozen_only.bracket_encounters.where(round: 1).order(:position).first
    end

    it "marks nothing movable, the way a non-admin render does" do
      expect(described_class.new(team_category: frozen_only, admin: true)
        .slot_source?(round_one_slot, 1)).to be true

      frozen_only.freeze_bracket!

      component = described_class.new(team_category: frozen_only.reload, admin: true)
      expect(component.slot_source?(round_one_slot, 1)).to be false
      expect(component.slot_target?(round_one_slot, 1)).to be false
    end

    it "still renders the tree and keeps its subscription" do
      frozen_only.freeze_bracket!

      html = render_inline(described_class.new(team_category: frozen_only.reload, admin: true)).to_html

      expect(html).to include("competition-tree")
      expect(html).to include("turbo-cable-stream-source")
    end
  end

  describe "manual reordering affordances" do
    let(:pooled) { create(:team_category, pool_size: 3, out_of_pool: 2) }

    def build_pooled(pools)
      (1..pools).each do |pool|
        (1..2).each { |rank| create(:team, team_category: pooled, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(pooled).call
      pooled.reload
    end

    it "makes a bye's empty side a drop target without growing the card" do
      build_pooled(3)
      bye = pooled.bracket_encounters.where(round: 1).detect(&:bye?)
      empty_slot = (bye.bye_slot == 1) ? 2 : 1

      render_inline(described_class.new(team_category: pooled, admin: true))

      strip = page.find("[data-slot-id='#{bye.id}-#{empty_slot}']")
      expect(strip[:class]).to include "competition-tree__bye-drop"
      # An empty slot sends an EMPTY expectation, not a missing one: "I believe
      # this is empty" is a belief the server can refuse.
      expect(strip["data-entry-key"]).to eq ""
      # The strip IS the header line, so every bye card keeps its one-line
      # height — one fighter row, not two.
      expect(page.all(".competition-tree__match--bye")).to all(have_css(".competition-tree__fighter", count: 1))
    end

    it "offers a Move to… select on every source slot" do
      build_pooled(2)

      render_inline(described_class.new(team_category: pooled, admin: true))

      expect(page).to have_css ".competition-tree__move-select", count: 4
    end

    it "keeps Remove from bracket off a bye, whose unit would be left empty" do
      build_pooled(3)

      render_inline(described_class.new(team_category: pooled, admin: true))

      bye_options = page.all(".competition-tree__match--bye option").map(&:text)
      expect(bye_options).not_to include "Remove from bracket"
      expect(page.all("option").map(&:text)).to include "Remove from bracket"
    end

    it "shows no affordance at all on a frozen bracket" do
      build_pooled(2)
      pooled.update!(bracket_frozen_at: Time.current)

      render_inline(described_class.new(team_category: pooled.reload, admin: true))

      expect(page).to have_no_css ".competition-tree__grip"
      expect(page).to have_no_css ".competition-tree__move-select"
      expect(page).to have_no_css "[data-slot-id]"
    end

    # Regression: swap_data read `team_#{slot}.id` unguarded, which is nil on a
    # pooled slot until the standings land.
    it "renders a pooled slot whose competitor is not resolved yet" do
      build_pooled(2)
      pooled.bracket_encounters.where(round: 1).find_each do |encounter|
        encounter.update_columns(team_1_id: nil, team_2_id: nil) # rubocop:disable Rails/SkipsModelValidations
      end

      expect { render_inline(described_class.new(team_category: pooled.reload, admin: true)) }
        .not_to raise_error
      expect(page).to have_css ".competition-tree__grip", minimum: 4
    end
  end
end
