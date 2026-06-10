# frozen_string_literal: true

# Swaps the occupants of two round-1 slots of a bracket-only elimination
# bracket — the admin's draw-correction tool. A swap always exchanges two
# occupied slots (the target team's current slot receives the displaced team),
# so the bracket can never end up with a duplicated or dropped team. Teams not
# in the bracket join via a rebuild, never a swap.
#
# Rejected unless every impacted encounter — both round-1 encounters plus any
# round-2 child fed by a bye among them — is pristine: no winner, no lineup,
# no recorded fight points.
class EncounterTeamSwap
  class InvalidSwap < StandardError; end

  def initialize(encounter)
    @encounter = encounter
    @category = encounter.team_category
  end

  # Whether the slot is offerable at all: bracket-only, round 1, occupied,
  # and this side's impacted encounters pristine. The other side's state is
  # only known at swap time and is validated there.
  def swappable?(slot)
    category.bracket_only? &&
      encounter.round == 1 &&
      occupant(slot).present? &&
      impacted(encounter).all? { |enc| pristine?(enc) }
  end

  # Teams an occupied slot can swap with: every other round-1 occupant.
  def candidates(slot)
    round_one.flat_map { |enc| [enc.team_1, enc.team_2] }.compact - [occupant(slot)]
  end

  def swap(slot, team)
    raise InvalidSwap, "swaps only apply to bracket-only categories" unless category.bracket_only?
    raise InvalidSwap, "only round-1 slots can be swapped" unless encounter.round == 1
    raise InvalidSwap, "invalid slot" unless [1, 2].include?(slot)

    current = occupant(slot)
    raise InvalidSwap, "this slot has no team to swap" if current.nil?
    raise InvalidSwap, "#{team.name} already occupies this slot" if team == current

    other_encounter, other_slot = locate(team)
    raise InvalidSwap, "#{team.name} is already in this encounter" if other_encounter == encounter

    validate_pristine!(other_encounter)

    Encounter.transaction do
      encounter.assign_team_to_slot(slot, team)
      other_encounter.assign_team_to_slot(other_slot, current)
    end
  end

  private attr_reader :encounter, :category

  private def occupant(slot)
    encounter.public_send(:"team_#{slot}")
  end

  private def round_one
    category.bracket_encounters.where(round: 1)
  end

  # The true-swap invariant needs the target in exactly one round-1 slot; a
  # team added after generation (or any drift) is rejected.
  private def locate(team)
    matches = round_one.where("team_1_id = :id OR team_2_id = :id", id: team.id).to_a
    unless matches.size == 1
      raise InvalidSwap,
        "#{team.name} does not occupy exactly one bracket slot — rebuild the bracket instead"
    end

    match = matches.first
    [match, (match.team_1_id == team.id) ? 1 : 2]
  end

  private def validate_pristine!(other_encounter)
    (impacted(encounter) + impacted(other_encounter)).uniq.each do |enc|
      next if pristine?(enc)

      raise InvalidSwap,
        "encounter #{enc.number} already has recorded results — clear them before swapping"
    end
  end

  # A bye's round-2 child slot changes with the bye's occupant, so it is part
  # of the swap's blast radius.
  private def impacted(enc)
    [enc] + (enc.bye? ? enc.children.to_a : [])
  end

  private def pristine?(enc)
    enc.winner_id.nil? && !enc.lineup_1_set? && !enc.lineup_2_set? &&
      enc.team_fights.none? { |fight| fight.fight_points.exists? }
  end
end
