# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team seeds" do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2, team_size: 3) }
  let(:admin) { create(:user, :admin) }
  let(:sequence) { (1..).each }

  before { sign_in admin }

  def team(seed: nil)
    create(:team, team_category: category, name: "Team #{sequence.next}", seed: seed)
  end

  def move(team, to_position)
    patch admin_team_category_seed_path(category, team),
      params: {to_position: to_position}, as: :turbo_stream
  end

  def unseed(team)
    delete admin_team_category_seed_path(category, team), as: :turbo_stream
  end

  def seeds_by_id = category.teams.reload.to_h { |t| [t.id, t.seed] }

  it "seeds a team and replaces the panel" do
    fresh = team

    move(fresh, 1)

    expect(response).to have_http_status(:success)
    expect(fresh.reload.seed).to eq 1
    expect(response.body).to include("target=\"team_seeds_#{category.id}\"")
  end

  it "reorders and renumbers the list" do
    a = team(seed: 1)
    b = team(seed: 2)
    c = team(seed: 3)

    move(c, 1)

    expect(seeds_by_id).to eq(c.id => 1, a.id => 2, b.id => 3)
  end

  it "unseeds on destroy and closes the gap" do
    a = team(seed: 1)
    b = team(seed: 2)
    c = team(seed: 3)

    unseed(a)

    expect(seeds_by_id).to eq(a.id => nil, b.id => 1, c.id => 2)
  end

  it "treats an update with a blank position as an unseed" do
    a = team(seed: 1)
    team(seed: 2)

    move(a, "")

    expect(a.reload.seed).to be_nil
  end

  # The panel is the only page element a seed change can make stale: the team
  # pool cards and the bracket carry no seed badge, unlike their individual
  # counterparts.
  it "replaces the panel and nothing else" do
    move(team, 1)

    expect(response.body.scan("<turbo-stream").size).to eq 1
  end

  # The panel's subscription and the controller's broadcast name the stream in
  # two different files, so a typo in either would silently stop other open
  # pages from following along — the acting admin would still see the change,
  # because their panel is replaced from the response, not the broadcast.
  # stream_name_from is private on Turbo's side; there is no public way to ask
  # what a pair of streamables resolves to.
  it "broadcasts on the stream the panel subscribes to" do
    stream = Turbo::StreamsChannel.send(:stream_name_from, [category, :team_seeds])
    fresh = team

    expect { move(fresh, 1) }
      .to have_broadcasted_to(stream).from_channel(Turbo::StreamsChannel)
  end

  it "refuses a team from another category" do
    other = create(:team_category, cup: cup, pool_size: 3)
    stranger = create(:team, team_category: other, name: "Stranger")

    move(stranger, 1)

    expect(response).to have_http_status(:not_found)
  end

  it "redirects a non-admin away" do
    sign_in create(:user)
    seeded = team(seed: 1)

    move(seeded, 1)

    expect(response).to redirect_to(root_url)
    expect(seeded.reload.seed).to eq 1
  end

  describe "a position that is not a position" do
    it "refuses a non-numeric position rather than reading it as 1" do
      a = team(seed: 1)
      b = team(seed: 2)

      move(b, "abc")

      expect(response).to have_http_status(:bad_request)
      expect([a.reload.seed, b.reload.seed]).to eq [1, 2]
    end

    it "refuses a zero or negative position" do
      b = team(seed: 1)

      move(b, "0")

      expect(response).to have_http_status(:bad_request)
      expect(b.reload.seed).to eq 1
    end

    it "refuses a non-scalar position" do
      b = team(seed: 1)

      patch admin_team_category_seed_path(category, b),
        params: {to_position: ["1"]}, as: :turbo_stream

      expect(response).to have_http_status(:bad_request)
      expect(b.reload.seed).to eq 1
    end
  end

  it "answers a move that changes nothing with no content" do
    team(seed: 1)
    b = team(seed: 2)

    move(b, 2)

    expect(response).to have_http_status(:no_content)
    expect(b.reload.seed).to eq 2
  end

  # The unseed control is a plain button_to, so a browser that never ran Turbo
  # has to get a page back rather than raw <turbo-stream> markup.
  it "redirects to the category when the request is not a turbo stream" do
    seeded = team(seed: 1)

    delete admin_team_category_seed_path(category, seeded)

    expect(response).to redirect_to(admin_team_category_path(category))
    expect(seeded.reload.seed).to be_nil
  end

  # A bracket-only category has no pools at all; seeding still has to work,
  # because its seeds decide the byes and the protected bracket positions.
  it "seeds a bracket-only category" do
    category.update!(pool_size: 1)
    fresh = team

    move(fresh, 1)

    expect(response).to have_http_status(:success)
    expect(fresh.reload.seed).to eq 1
  end
end
