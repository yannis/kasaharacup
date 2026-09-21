# frozen_string_literal: true

# Swaps the occupants of two round-1 slots of a bracket-only elimination
# bracket — the admin's draw-correction tool. A swap always exchanges two
# occupied slots (the target team's current slot receives the displaced team),
# so the bracket can never end up with a duplicated or dropped team. Teams not
# in the bracket join via a rebuild, never a swap.
#
# Rejected unless every impacted encounter — both round-1 encounters plus any
# round-2 child fed by a bye among them — is unscored: no winner, no recorded
# fight point and no bout the admin marked hikiwake. A merely auto-seeded
# lineup does not block a swap and does not prompt either: it is an order
# nobody chose. Only an order an admin entered by hand asks for confirmation
# (see #validate_confirmed_lineups! and Encounter#hand_ordered?).
class EncounterTeamSwap
  class InvalidSwap < StandardError; end

  # A swap that is legal but would discard a fighter order an admin entered by
  # hand. Separate from InvalidSwap because the client can act on it: confirm,
  # then retry with force: true — the same shape TeamPoolMove uses for a
  # destructive pool move.
  class NeedsConfirmation < StandardError; end

  SLOTS = [1, 2].freeze

  # The tail of every confirmation message. A constant because the panel form's
  # refusal path rewrites it into an instruction — the flash cannot be answered
  # the way a confirm dialog can (Admin::Encounters::TeamSwapsController#refuse).
  CONFIRM_QUESTION = "Swap anyway?"

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
      next if ineligibility_reason(enc)
      next unless impacted_in_memory(enc, children).all?(&:unscored?)

      SLOTS.each do |slot|
        slots << [enc.id, slot] if enc.public_send(:"team_#{slot}").present?
      end
    end
  end

  # The per-encounter half of eligibility, shared by the tree (.swappable_slots)
  # and the write path (#swap) so the two can never disagree about what may
  # move. Returns nil when the encounter qualifies, or the reason it does not.
  #
  # The pool_number guard is not redundant for a caller-supplied list: both
  # in-app callers pass TeamCategory#bracket_encounters (already scoped to
  # pool_number: nil), but this is public API over a list we do not build.
  def self.ineligibility_reason(enc)
    return "encounter #{enc.number} is not part of the bracket" if enc.pool_number.present?
    return "only round-1 slots can be swapped" unless enc.round == 1

    # A bracket-only category whose pool_size was lowered can still hold round-1
    # encounters seeded from pool standings. Swapping one writes team ids that
    # TeamCategoryBracketBuilder#update_team_slot re-resolves from this metadata
    # on the next build, silently undoing the swap.
    if enc.team_1_pool_number.present? || enc.team_2_pool_number.present?
      return "encounter #{enc.number} is still seeded from pool standings — rebuild the bracket instead"
    end

    nil
  end

  # The prompt a swap over these encounters owes the admin, or nil when it
  # would discard no fighter order anyone entered. Shared by the write path
  # (#validate_confirmed_lineups!) and the panel form (#confirmation_for), so
  # what the form asks and what the server refuses can never disagree.
  def self.confirmation_message(impacted_encounters)
    # Decide on #hand_ordered? FIRST, label SECOND. encounters.number is
    # nullable, so filter_mapping the label in one pass would drop a numberless
    # row out of the check entirely and return nil — failing OPEN on exactly
    # the order this exists to protect.
    hand_ordered = impacted_encounters.select(&:hand_ordered?)
    return if hand_ordered.empty?

    numbers = hand_ordered.filter_map(&:number).sort
    subject = case numbers.size
    when 0 then "another encounter"
    when 1 then "encounter #{numbers.first}"
    else "encounters #{numbers.to_sentence}"
    end
    "This clears the fighter order entered on #{subject}. #{CONFIRM_QUESTION}"
  end

  # The bracket, loaded the way both entry points above need it.
  def self.bracket_for(category)
    list = category.bracket_encounters
      .includes(:team_1, :team_2, team_fights: :fight_points)
      .bracket_order.to_a
    Encounter.preload_parents(list)
    list
  end

  # Internal, but shared with the instance side (see #impacted_from_bracket):
  # both answer questions about a bye's blast radius from an already-loaded
  # list rather than firing #children per node.
  def self.children_by_parent_id(encounters)
    encounters.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |enc, lookup|
      lookup[enc.parent_encounter_1_id] << enc if enc.parent_encounter_1_id
      lookup[enc.parent_encounter_2_id] << enc if enc.parent_encounter_2_id
    end
  end

  def self.impacted_in_memory(enc, children)
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
    swappable_slot_set.include?([encounter.id, slot])
  end

  # Teams this encounter can swap with: the occupants of every OTHER slot the
  # tree would let you drag. BOTH of its own teams are excluded — swapping a
  # match's two sides only flips which is team_1, and #swap rejects it. Slots
  # #swap would refuse (already scored, still pool-seeded) are excluded for the
  # same reason: offering them was an option that could only ever error.
  def candidates
    bracket.flat_map { |enc|
      SLOTS.filter_map do |slot|
        enc.public_send(:"team_#{slot}") if swappable_slot_set.include?([enc.id, slot])
      end
    } - [encounter.team_1, encounter.team_2].compact
  end

  # The prompt the panel's select form owes before swapping `team` into this
  # encounter, or nil when the swap would discard no hand-entered order. The
  # form cannot let the server decide: the partner is only known once a team is
  # picked from the dropdown, and by then the answer has to be in the page. So
  # it asks per option, off the bracket already loaded for #candidates — no
  # query of its own, and the same verdict #swap would reach.
  #
  # nil for a team the bracket does not hold: #swap refuses that outright, and
  # a prompt is not how a refusal is reported.
  def confirmation_for(team)
    other = encounter_holding(team)
    return unless other

    impacted = (impacted_from_bracket(encounter) + impacted_from_bracket(other)).uniq
    self.class.confirmation_message(impacted)
  end

  # `expected_team_id` and `expected_encounter_id` are the target slot's
  # occupant and the dragged team's encounter as the CLIENT believes them. The
  # bracket tree morphs from a broadcast, so a drop can be issued against a tree
  # drawn before someone else's swap landed; checking BOTH ends turns a silent
  # mis-swap into a reload prompt. The target alone is not enough — #locate
  # re-resolves the dragged team to wherever it sits *now*, which may be an
  # encounter the admin never looked at.
  #
  # `force` skips the confirmation prompt; see #validate_confirmed_lineups!.
  def swap(slot, team, expected_team_id: nil, expected_encounter_id: nil, force: false)
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
    if expected_encounter_id.present? && other_encounter.id != expected_encounter_id.to_i
      raise InvalidSwap, "#{team.name} has moved — reload and try again"
    end

    validate_eligible!(other_encounter)
    validate_distinct_bye_children!(other_encounter)

    Encounter.transaction do
      # Lock EVERY row this swap can write — the two round-1 rows AND any
      # bye-fed round-2 child, which Encounter#propagate_bye_to_children
      # re-draws. Ascending id order: two opposing swaps take the rows in the
      # same sequence, so they serialize instead of deadlocking. lock! reloads
      # each row, which also clears the association cache we re-read below.
      impacted_encounters = (impacted(encounter) + impacted(other_encounter)).uniq
      impacted_encounters.sort_by(&:id).each(&:lock!)

      # Everything above was read before the locks and is stale by definition.
      current = occupant(slot)
      raise InvalidSwap, "this slot has no team to swap" if current.nil?

      if expected_team_id.present? && current.id != expected_team_id.to_i
        raise InvalidSwap, "the bracket changed since this page was drawn — reload and try again"
      end
      if other_encounter.public_send(:"team_#{other_slot}_id") != team.id
        raise InvalidSwap, "#{team.name} has moved — reload and try again"
      end

      validate_unscored!(impacted_encounters)
      validate_confirmed_lineups!(impacted_encounters) unless force

      # Each assignment discards the encounter's stale matchup on its way
      # through Encounter#invalidate_matchup, and a bye's round-2 child is
      # re-drawn the same way by the bye-propagation callback.
      encounter.assign_team_to_slot(slot, team)
      other_encounter.assign_team_to_slot(other_slot, current)
    end
  end

  private attr_reader :encounter, :category

  private def bracket
    @bracket ||= self.class.bracket_for(category)
  end

  # Memoised: the panel asks #swappable? once per slot and then builds
  # #candidates, and the Set is derived from the same already-loaded bracket.
  private def swappable_slot_set
    @swappable_slot_set ||= self.class.swappable_slots(bracket, category: category)
  end

  private def occupant(slot)
    encounter.public_send(:"team_#{slot}")
  end

  # The bracket row that holds `team` in a round-1 slot, read from the loaded
  # list — #locate's in-memory twin, for the read path that must not query.
  private def encounter_holding(team)
    bracket.detect do |enc|
      enc.round == 1 && (enc.team_1_id == team.id || enc.team_2_id == team.id)
    end
  end

  private def children_lookup
    @children_lookup ||= self.class.children_by_parent_id(bracket)
  end

  private def impacted_from_bracket(enc)
    self.class.impacted_in_memory(enc, children_lookup)
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

  # The tree's own eligibility rules, enforced where it counts: the write path.
  # Both ends have to qualify. The tree hides a pool-seeded slot, but a swap
  # reaching this service from the panel's select (or a hand-rolled POST) would
  # otherwise land and be silently reverted by the next bracket build.
  private def validate_eligible!(other_encounter)
    [encounter, other_encounter].each do |enc|
      reason = self.class.ineligibility_reason(enc)
      raise InvalidSwap, reason if reason
    end
  end

  # Two byes that feed the SAME round-2 encounter cannot exchange occupants:
  # the first #assign_team_to_slot propagates its new occupant into the child
  # while the child's other slot still holds that very team, which
  # Encounter#teams_differ rejects — an ActiveRecord::RecordInvalid that escapes
  # the caller's InvalidSwap rescue as a 500. The draw itself is what needs
  # fixing there, so the remedy is a rebuild.
  #
  # Only the PAIR is refused, not the slots: either bye can still be swapped
  # with any encounter it does not already meet in round 2, so both keep their
  # grips.
  private def validate_distinct_bye_children!(other_encounter)
    return unless encounter.bye? && other_encounter.bye?
    return if (encounter.children.ids & other_encounter.children.ids).empty?

    raise InvalidSwap,
      "encounters #{encounter.number} and #{other_encounter.number} already meet in round 2 " \
      "— rebuild the bracket instead of swapping them"
  end

  # Raises unless every impacted encounter is free of recorded results.
  private def validate_unscored!(impacted_encounters)
    impacted_encounters.each do |enc|
      next if enc.unscored?

      raise InvalidSwap,
        "encounter #{enc.number} already has recorded results — clear them before swapping"
    end
  end

  # #unscored? (the eligibility bar) deliberately ignores the lineup flags:
  # EncounterLineupSeeder confirms both the moment an admin opens a panel, so
  # gating eligibility on them made the tool withdraw itself on sight. A
  # hand-entered order is protected by this prompt instead — and only a
  # hand-entered one, which is what Encounter#hand_ordered? answers. Same shape
  # as TeamPoolMove's :needs_confirmation.
  private def validate_confirmed_lineups!(impacted_encounters)
    message = self.class.confirmation_message(impacted_encounters)
    raise NeedsConfirmation, message if message
  end

  # A bye's round-2 child slot changes with the bye's occupant, so it is part
  # of the swap's blast radius.
  private def impacted(enc)
    [enc] + (enc.bye? ? enc.children.to_a : [])
  end
end
