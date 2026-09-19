# frozen_string_literal: true

# The seeding panel of a team category's admin page: the seeded teams in seed
# order, a select to seed another, and the reminder of when the seeds take
# effect. Twin of IndividualSeedsComponent, over Team instead of Participation.
#
# Lists only the seeded, as the individual panel does: a category can hold
# dozens of teams and typically has four seeds.
#
# The root element always renders (even with no seeds) so a Turbo Stream replace
# always has a target after the last seed is removed.
class TeamSeedsComponent < ViewComponent::Base
  def initialize(category:)
    @category = category
  end

  private attr_reader :category

  # Both lists are slices of the same set, so it is loaded once. The roster is
  # preloaded because every seeded row names its clubs and its member count.
  private def teams
    @teams ||= category.teams.includes(participations: {kenshi: :club}).to_a
  end

  # Walks participations, not the kenshis has_many :through. The preload above
  # populates :participations (and the kenshi and club hanging off it) but NOT
  # the separate :kenshis association, so reading team.kenshis here would query
  # again per row and then once more per kenshi for the club — paying for the
  # preload and N+1-ing anyway.
  private def clubs_of(team)
    team.participations.filter_map { |participation| participation.kenshi&.club }.uniq.join(", ")
  end

  # Where the individual panel shows a grade, a team's telling detail is
  # whether it can actually field a squad.
  private def roster_of(team)
    return "complete" if team.complete?

    "#{team.participations.size}/#{team.team_size}"
  end

  private def seeded
    @seeded ||= Team.in_seed_order(teams)
  end

  private def unseeded
    @unseeded ||= teams.reject(&:seeded?).sort_by { |team| team.name.to_s }
  end

  private def positions
    (1..seeded.size).to_a
  end

  # What the add select sends: the position a newly seeded team takes.
  private def next_position
    seeded.size + 1
  end

  private def dom_id_for_seeds
    "team_seeds_#{category.id}"
  end

  private def seed_url(team)
    helpers.admin_team_category_seed_path(category, team)
  end

  # Unlike an individual category, a team category's seeds matter in BOTH modes:
  # a pooled category spreads them across the pools on the next pool draw, and
  # a bracket-only one hands them the byes and the protected bracket positions
  # on the next bracket build. The hint has to say which.
  #
  # The pooled wording names "Generate pools", NOT the individual side's "Smart
  # pool reset" — that action_item exists only on IndividualCategory. And it
  # cannot promise the individual panel's "nobody already pooled moves":
  # TeamPooler#set_pools redraws from scratch, reshuffling every unseeded team,
  # which is why that button confirms with "Manual pool assignments are lost".
  private def effect_hint
    if category.bracket_only?
      "Seeds apply on the next bracket build — they decide the byes and keep the seeds apart in the draw."
    else
      "Seeds apply the next time you Generate pools — which redraws every pool, so manual pool assignments are lost."
    end
  end
end
