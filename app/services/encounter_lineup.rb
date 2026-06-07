# frozen_string_literal: true

# Assigns one team's ordered members to its side of every bout in an encounter,
# creating the team_size TeamFight rows on first use. Positions past the supplied
# list keep a nil kenshi on that side (a forfeit). Re-assigning a side overwrites
# only that side's kenshi at each position.
class EncounterLineup
  class InvalidLineup < StandardError; end

  def initialize(encounter)
    @encounter = encounter
    @team_size = encounter.team_size
  end

  def assign(team, kenshi_ids)
    kenshi_ids = kenshi_ids.compact.map(&:to_i)
    slot = slot_for(team)
    validate!(team, kenshi_ids)

    @encounter.transaction do
      (1..@team_size).each do |position|
        fight = @encounter.team_fights.find_or_create_by!(position: position)
        fight.update!("kenshi_#{slot}_id": kenshi_ids[position - 1])
      end
      @encounter.update!("lineup_#{slot}_set": true)
      resolve_forfeits if @encounter.lineup_1_set? && @encounter.lineup_2_set?
    end
  end

  private def resolve_forfeits
    @encounter.team_fights.reset
    @encounter.team_fights.each(&:resolve_lineup!)
  end

  private def slot_for(team)
    return 1 if team.id == @encounter.team_1_id
    return 2 if team.id == @encounter.team_2_id

    raise InvalidLineup, "team is not part of this encounter"
  end

  private def validate!(team, kenshi_ids)
    raise InvalidLineup, "too many members" if kenshi_ids.size > @team_size
    raise InvalidLineup, "duplicate members" if kenshi_ids.uniq.size != kenshi_ids.size

    on_team = team.kenshis.where(id: kenshi_ids).pluck(:id)
    raise InvalidLineup, "member not on team" if (kenshi_ids - on_team).any?
  end
end
