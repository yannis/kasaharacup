# frozen_string_literal: true

# Swaps the occupants of two round-1 slots of a bracket-only elimination
# bracket — the admin's draw-correction tool. A swap always exchanges two
# occupied slots (the target team's current slot receives the displaced team),
# so the bracket can never end up with a duplicated or dropped team. Teams not
# in the bracket join via a rebuild, never a swap.
#
# Rejected unless every impacted encounter — both round-1 encounters plus any
# round-2 child fed by a bye among them — is unscored: no winner and no
# recorded fight points. A merely auto-seeded lineup does not block a swap
# (see Encounter#unscored?).
class EncounterTeamSwap
  class InvalidSwap < StandardError; end

  SLOTS = [1, 2].freeze

  # Eligibility for a WHOLE bracket, answered from an already-loaded list.
  # The tree renders every node on every render and on every broadcast morph,
  # so a per-node service instance (each firing #children for a bye) would be
  # an N+1 in the hot path. Callers pass the list they already preloaded with
  # `:team_1, :team_2, team_fights: :fight_points` and Encounter.preload_parents;
  # children are derived here by inverting the parent pointers in memory.
  #
  # `category` is passed rather than read off an encounter so this fires no
  # query of its own even if the list arrived without its inverse association.
  #
  # Returns a Set of [encounter_id, slot] pairs.
  def self.swappable_slots(encounters, category:)
    return Set.new unless category.bracket_only?

    children = children_by_parent_id(encounters)

    encounters.each_with_object(Set.new) do |enc, slots|
      next unless enc.round == 1 && enc.pool_number.blank?
      next if pool_seeded?(enc)
      next unless impacted_in_memory(enc, children).all?(&:unscored?)

      SLOTS.each do |slot|
        slots << [enc.id, slot] if enc.public_send(:"team_#{slot}").present?
      end
    end
  end

  # Every round-1 occupant in the bracket — the pool a slot's swap candidates
  # are drawn from.
  def self.round_one_occupants(encounters)
    encounters.select { |enc| enc.round == 1 }
      .flat_map { |enc| [enc.team_1, enc.team_2] }.compact
  end

  # The bracket, loaded the way both entry points above need it.
  def self.bracket_for(category)
    list = category.bracket_encounters
      .includes(:team_1, :team_2, team_fights: :fight_points)
      .bracket_order.to_a
    Encounter.preload_parents(list)
    list
  end

  # A bracket-only category whose pool_size was lowered can still hold round-1
  # encounters seeded from pool standings. Swapping one writes team ids that
  # TeamCategoryBracketBuilder#update_team_slot re-resolves from this metadata
  # on the next build, silently undoing the swap.
  private_class_method def self.pool_seeded?(enc)
    enc.team_1_pool_number.present? || enc.team_2_pool_number.present?
  end

  private_class_method def self.children_by_parent_id(encounters)
    encounters.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |enc, lookup|
      lookup[enc.parent_encounter_1_id] << enc if enc.parent_encounter_1_id
      lookup[enc.parent_encounter_2_id] << enc if enc.parent_encounter_2_id
    end
  end

  private_class_method def self.impacted_in_memory(enc, children)
    [enc] + (enc.bye? ? children[enc.id] : [])
  end

  def initialize(encounter)
    @encounter = encounter
    @category = encounter.team_category
  end

  # One slot, for the encounter panel's select form. Loads the bracket to answer
  # it — one query for a dozen rows, once per panel render — so the panel and the
  # tree can never disagree about what is swappable.
  def swappable?(slot)
    self.class.swappable_slots(bracket, category: category).include?([encounter.id, slot])
  end

  # Teams this encounter can swap with: every other round-1 occupant. BOTH of
  # its own teams are excluded — swapping a match's two sides only flips which
  # is team_1, and #swap rejects it, so offering the sibling was an option that
  # could only ever error.
  def candidates
    self.class.round_one_occupants(bracket) - [encounter.team_1, encounter.team_2].compact
  end

  # `expected_team_id` is the team the CLIENT believes occupies the slot. The
  # bracket tree morphs from a broadcast, so a drop can be issued against a tree
  # drawn before someone else's swap landed; checking it turns a silent
  # mis-swap into a reload prompt.
  def swap(slot, team, expected_team_id: nil)
    raise InvalidSwap, "swaps only apply to bracket-only categories" unless category.bracket_only?
    raise InvalidSwap, "only round-1 slots can be swapped" unless encounter.round == 1
    raise InvalidSwap, "invalid slot" unless SLOTS.include?(slot)

    # Slot-level complaints come BEFORE locate(): re-selecting the team already
    # in this slot must report "already occupies this slot", not locate()'s
    # "already in this encounter".
    raise InvalidSwap, "this slot has no team to swap" if occupant(slot).nil?
    raise InvalidSwap, "#{team.name} already occupies this slot" if team == occupant(slot)

    other_encounter, other_slot = locate(team)
    raise InvalidSwap, "#{team.name} is already in this encounter" if other_encounter == encounter

    Encounter.transaction do
      # Ascending id order: two opposing swaps take the rows in the same
      # sequence, so they serialize instead of deadlocking. lock! reloads each
      # row, which also clears the association cache we re-read below.
      [encounter, other_encounter].sort_by(&:id).each(&:lock!)

      # Everything above was read before the locks and is stale by definition.
      current = occupant(slot)
      raise InvalidSwap, "this slot has no team to swap" if current.nil?

      if expected_team_id.present? && current.id != expected_team_id.to_i
        raise InvalidSwap, "the bracket changed since this page was drawn — reload and try again"
      end
      if other_encounter.public_send(:"team_#{other_slot}_id") != team.id
        raise InvalidSwap, "#{team.name} has moved — reload and try again"
      end

      # Covers both sides plus any bye-fed round-2 child.
      impacted_encounters = validate_unscored!(other_encounter)

      # Re-drawing wipes whatever was seeded, on BOTH sides and on every
      # impacted encounter — see #clear_seeded_lineup!.
      impacted_encounters.each { |enc| clear_seeded_lineup!(enc) }

      encounter.assign_team_to_slot(slot, team)
      other_encounter.assign_team_to_slot(other_slot, current)
    end
  end

  private attr_reader :encounter, :category

  private def bracket
    @bracket ||= self.class.bracket_for(category)
  end

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

  # Raises unless every impacted encounter is unscored; returns them so the
  # caller can reset them without walking the graph twice.
  private def validate_unscored!(other_encounter)
    (impacted(encounter) + impacted(other_encounter)).uniq.each do |enc|
      next if enc.unscored?

      raise InvalidSwap,
        "encounter #{enc.number} already has recorded results — clear them before swapping"
    end
  end

  # A draw correction re-draws the encounter, so a lineup that was merely
  # SEEDED (auto-filled the moment an admin opened the panel) has to go with it.
  #
  # #assign_team_to_slot invalidates only the side it rewrites. Left alone, the
  # untouched side kept its fighters and its lineup flag, so every bout had
  # exactly one side present — a forfeit (TeamFight#forfeit) — and
  # recompute_winner! handed the incoming team a 3-0 defeat it never fought.
  # The recorded winner then made the slot permanently unswappable, which is the
  # dead end this whole feature exists to remove.
  #
  # Destroying the bouts is safe precisely here: #validate_unscored! has already
  # proved there is no winner and no fight point, so nothing but seeded fighter
  # assignments can be lost, and reopening the panel re-seeds from the new
  # occupants.
  private def clear_seeded_lineup!(enc)
    enc.team_fights.destroy_all
    enc.update!(lineup_1_set: false, lineup_2_set: false)
  end

  # A bye's round-2 child slot changes with the bye's occupant, so it is part
  # of the swap's blast radius.
  private def impacted(enc)
    [enc] + (enc.bye? ? enc.children.to_a : [])
  end
end
