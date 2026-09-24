# frozen_string_literal: true

# Puts a team category's existing pool encounters on the sides
# Pools::TeamFightOrder gives them. PoolEncounterGenerator draws new pools that
# way; pools drawn before it keep the sides CyclicPairing's order gave them
# until this runs over them (see lib/tasks/temporary/pools.rake).
#
# A side is more than its team: the lineup flags and each bout's fighter go
# with it, so a swapped encounter keeps any fighter order already entered. The
# columns are written directly — assigning a team through the model would run
# Encounter#invalidate_matchup and throw that order away.
#
# Only unscored encounters are swapped: points are keyed by fighter side, and a
# decided bout's winner belongs to one. The rest are reported, not touched, as
# are encounters whose teams no longer make a pair of the pool.
class PoolEncounterReorientation
  Result = Data.define(:swapped, :skipped)

  def initialize(team_category)
    @team_category = team_category
  end

  def call(dry_run: false)
    swapped = []
    skipped = []
    team_category.transaction do
      misoriented.each do |encounter|
        if swappable?(encounter)
          swap!(encounter) unless dry_run
          swapped << encounter
        else
          skipped << encounter
        end
      end
    end
    Result.new(swapped: swapped, skipped: skipped)
  end

  private attr_reader :team_category

  # The encounters whose red team is the one TeamFightOrder puts on white.
  private def misoriented
    encounters = team_category.encounters.where.not(pool_number: nil)
      .includes(team_fights: :fight_points).group_by(&:pool_number)
    team_category.team_pools.flat_map do |pool|
      whites = expected_whites(pool)
      encounters.fetch(pool.number, []).select do |encounter|
        whites[[encounter.team_1_id, encounter.team_2_id].to_set] == encounter.team_2_id
      end
    end
  end

  # {pair of team ids => the white one's id}, for every tie of the pool.
  private def expected_whites(pool)
    ids = pool.teams.map(&:id)
    Pools::TeamFightOrder.sides_for(ids.size).to_h do |white, red|
      [[ids[white - 1], ids[red - 1]].to_set, ids[white - 1]]
    end
  end

  private def swappable?(encounter)
    encounter.unscored? && encounter.team_fights.none?(&:winner_id)
  end

  # Through update_all, so the returned records still show the sides they had
  # and a report can say what each was swapped from, dry run or not.
  private def swap!(encounter)
    Encounter.where(id: encounter.id).update_all(
      team_1_id: encounter.team_2_id, team_2_id: encounter.team_1_id,
      lineup_1_set: encounter.lineup_2_set, lineup_2_set: encounter.lineup_1_set,
      lineup_1_set_by_admin: encounter.lineup_2_set_by_admin,
      lineup_2_set_by_admin: encounter.lineup_1_set_by_admin,
      updated_at: Time.current
    )
    encounter.team_fights.each do |fight|
      TeamFight.where(id: fight.id)
        .update_all(kenshi_1_id: fight.kenshi_2_id, kenshi_2_id: fight.kenshi_1_id, updated_at: Time.current)
    end
  end
end
