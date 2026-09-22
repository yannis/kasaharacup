# frozen_string_literal: true

# Places, exchanges and removes the entries of a bracket's round-1 slots — the
# organizers' draw-correction tool, for pooled and pool-less categories and for
# both bracket kinds. Replaces EncounterTeamSwap, whose guards all survive here;
# what changed is that a slot's whole ENTRY moves, pool label included, so a
# pooled category is now the main case rather than a refusal.
#
# Refuses unless every impacted record is unscored: the record itself plus its
# children, which a bye advances into and which a unit changing its bye-ness
# rewrites. A merely auto-seeded lineup does not block a move and does not
# prompt either — only an order an admin entered by hand asks for confirmation
# (see #validate_confirmed_lineups! and Encounter#hand_ordered?).
class BracketSlotMove
  class InvalidMove < StandardError; end

  # A move that is legal but would discard a fighter order an admin entered by
  # hand. Separate from InvalidMove because the client can act on it: confirm,
  # then retry with force: true — the same shape TeamPoolMove uses.
  class NeedsConfirmation < StandardError; end

  SLOTS = BracketSlots::SLOTS

  # What the tree may offer, for a WHOLE bracket, answered from an
  # already-loaded list. The tree renders every node on every morph, so a
  # per-node service instance (each firing #children for a bye) would be an N+1
  # in the hot path.
  #
  # TWO sets where the swap tool had one, because the gestures pulled them
  # apart: a slot can be a drag SOURCE (it holds an entry that may leave) or a
  # drop TARGET (it may receive one). A bye's empty side is a target and never a
  # source, which is why the tree could not offer it before.
  Eligibility = Data.define(:sources, :targets)

  def self.eligibility(records)
    sources = Set.new
    targets = Set.new

    eligible_records(records).each do |record|
      SLOTS.each do |slot|
        targets << [record.id, slot]
        sources << [record.id, slot] if record.slot_occupied?(slot)
      end
    end

    Eligibility.new(sources: sources, targets: targets)
  end

  # The bracket, loaded the way the trees and this service both need it.
  def self.bracket_for(category)
    list = category.bracket_records.with_slot_move_context.bracket_order.to_a
    list.first&.class&.preload_parents(list)
    list
  end

  # The prompt a move over these records owes the admin, or nil when it would
  # discard no fighter order anyone entered.
  def self.confirmation_message(impacted)
    # Decide on #hand_ordered? FIRST, label SECOND. `number` is nullable, so
    # filter_mapping the label in one pass would drop a numberless row out of
    # the check entirely and return nil — failing OPEN on exactly the order this
    # exists to protect.
    hand_ordered = impacted.select { |record| record.respond_to?(:hand_ordered?) && record.hand_ordered? }
    return if hand_ordered.empty?

    numbers = hand_ordered.filter_map(&:number).sort
    subject = case numbers.size
    when 0 then "another encounter"
    when 1 then "encounter #{numbers.first}"
    else "encounters #{numbers.to_sentence}"
    end
    "This clears the fighter order entered on #{subject}. Move anyway?"
  end

  def self.eligible_records(records)
    children = children_by_parent_id(records)

    records.select do |record|
      record.round == 1 && record.pool_number.nil? &&
        impacted_in_memory(record, children).all?(&:unscored?)
    end
  end

  # Both entry points answer questions about a unit's blast radius from an
  # already-loaded list rather than firing #children per node.
  def self.children_by_parent_id(records)
    records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, lookup|
      parent_ids(record).each { |parent_id| lookup[parent_id] << record }
    end
  end

  def self.parent_ids(record)
    record.class::PARENT_ASSOCIATIONS.filter_map { |name| record.public_send(:"#{name}_id") }
  end

  # EVERY child, not only a bye's. A removal turns a two-entry unit INTO a bye
  # and propagation then rewrites the child that a pre-move `bye?` test would
  # never have put in the set — so it would be neither locked nor checked for
  # results. The extra strictness costs nothing: a non-bye parent's child can
  # only be scored once the parent has a winner, which is already refused.
  def self.impacted_in_memory(record, children)
    [record] + children[record.id]
  end

  def initialize(category)
    @category = category
  end

  # PATCH. `target` is "<record id>-<slot>"; the source is either another slot
  # ref or a waiting entry's key. `expected_entry` / `expected_source_entry` are
  # the two ends as the CLIENT believes them — an EMPTY STRING means "I believe
  # this slot is empty", which is not the same as nil, "I have no belief".
  def place(target:, source: nil, entry_key: nil,
    expected_entry: nil, expected_source_entry: nil, force: false)
    apply!(force: force) do
      target_record, target_slot = locate!(target)
      check_expectation!(target_record, target_slot, expected_entry)

      if source.present?
        writes_for_slot_source(target_record, target_slot, source, expected_source_entry)
      elsif entry_key.present?
        [[target_record, target_slot, waiting_entry!(entry_key)]]
      else
        raise InvalidMove, "there is nothing to put in this slot"
      end
    end
  end

  # DELETE. Empties a slot; its partner is left with a bye.
  def remove(target:, expected_entry: nil, force: false)
    apply!(force: force) do
      record, slot = locate!(target)
      check_expectation!(record, slot, expected_entry)
      raise InvalidMove, "this slot is already empty" unless record.slot_occupied?(slot)

      validate_unit_keeps_an_entry!(record, slot)
      [[record, slot, nil]]
    end
  end

  private attr_reader :category

  private def writes_for_slot_source(target_record, target_slot, source, expected_source_entry)
    source_record, source_slot = locate!(source)
    if source_record.id == target_record.id
      raise InvalidMove, "that entry is already in this slot" if source_slot == target_slot

      # The whole UNIT, not just the slot. Exchanging a unit's two sides only
      # flips which is slot 1, and on an Encounter the first write puts one team
      # id into both columns, which #teams_differ rejects — an
      # ActiveRecord::RecordInvalid that escapes the caller's rescue as a 500.
      # #move_options leaves a unit's own slots out for the same reason; this is
      # the write path saying so too, since the drag client is not the rule.
      raise InvalidMove,
        "that entry is already in this #{target_record.model_name.human.downcase}"
    end

    check_expectation!(source_record, source_slot, expected_source_entry)

    moving = source_record.slot_entry(source_slot)
    raise InvalidMove, "this slot has nothing to move" if moving.nil?

    displaced = target_record.slot_entry(target_slot)
    # A swap hands the source unit the displaced entry, so its count is
    # unchanged. A move into an EMPTY slot does not, and a bye's only entry
    # leaving empties the unit outright.
    validate_unit_keeps_an_entry!(source_record, source_slot) if displaced.nil?
    validate_distinct_bye_children!(target_record, source_record)

    [[target_record, target_slot, moving], [source_record, source_slot, displaced]]
  end

  # The shared body of every gesture: lock, re-read, validate, write.
  #
  # Returns true when anything actually changed. The caller needs the answer: a
  # descriptor-only write saves no competitor-id change, so neither model's tree
  # broadcast fires and the controller's own broadcast is the only redraw.
  private def apply!(force:)
    category.transaction do
      # EVERY round-1 row, ascending by id, before a single value is read. The
      # duplicate-placement refusal is a statement about the whole round, so the
      # rows it is derived from have to be the rows we hold; and taking them all
      # in one order means two opposing moves serialize instead of deadlocking.
      round_one_locked

      writes = yield
      records = writes.map(&:first).uniq(&:id)
      impacted = lock_impacted!(records)

      validate_unscored!(impacted)
      validate_confirmed_lineups!(impacted) unless force

      writes.map { |record, slot, entry| record.assign_slot_entry(slot, entry) }.any?
    end
  end

  # Everything read before the locks is stale by definition, so the whole round
  # is re-read here and every later lookup goes through this list.
  private def round_one_locked
    @round_one_locked ||= category.bracket_records.where(round: 1).order(:id).lock.to_a
  end

  # The children live outside round 1, so they are not in the set above. Taken
  # after it, in id order, which is safe because every transaction takes the
  # whole of round 1 first and therefore never interleaves here.
  private def lock_impacted!(records)
    children = records.flat_map { |record| record.children.to_a }.uniq(&:id)
    children.sort_by(&:id).each(&:lock!)
    (records + children).uniq(&:id)
  end

  private def locate!(ref)
    record_id, slot = ref.to_s.split("-", 2)
    slot = slot.to_i
    raise InvalidMove, "invalid slot" unless SLOTS.include?(slot)

    record = round_one_locked.detect { |candidate| candidate.id == record_id.to_i }
    raise InvalidMove, "only round-1 slots can be moved" if record.nil?

    [record, slot]
  end

  # nil means "the client expressed no belief"; "" means "the client believes
  # this slot is empty", which is a belief that can be wrong and must be checked
  # — otherwise a drop aimed at a bye's empty side silently overwrites whatever
  # someone else put there in the meantime.
  private def check_expectation!(record, slot, expected)
    return if expected.nil?
    return if record.slot_entry(slot)&.key.to_s == expected.to_s

    raise InvalidMove, "the bracket changed since this page was drawn — reload and try again"
  end

  private def validate_unit_keeps_an_entry!(record, slot)
    other = SLOTS.detect { |candidate| candidate != slot }
    return if record.slot_occupied?(other)

    raise InvalidMove,
      "that would leave a unit with nobody in it — use Force rebuild to draw a smaller field"
  end

  # Two byes feeding the SAME round-2 node cannot exchange occupants ON A RECORD
  # TYPE THAT SEEDS ITS CHILDREN: the first write propagates its new occupant
  # into the child while the child's other slot still holds that very entry,
  # which Encounter#teams_differ rejects — an ActiveRecord::RecordInvalid that
  # escapes the caller's rescue as a 500. The draw itself is what needs fixing
  # there, so the remedy is a rebuild.
  #
  # A Fight resolves its children lazily and stores nothing, so nothing can
  # collide and the exchange is simply allowed — refusing it there would cost
  # the admin a legal move and point them at a rebuild they do not need.
  #
  # Only the PAIR is refused, not the slots: either bye can still be moved
  # against any unit it does not already meet in round 2, so both keep grips.
  private def validate_distinct_bye_children!(target_record, source_record)
    return unless target_record.seeds_child_slots?
    return unless target_record.bye? && source_record.bye?
    return if (target_record.children.ids & source_record.children.ids).empty?

    raise InvalidMove,
      "those two byes already meet in round 2 — rebuild the bracket instead of exchanging them"
  end

  private def validate_unscored!(impacted)
    impacted.each do |record|
      next if record.unscored?

      raise InvalidMove,
        "#{record.model_name.human.downcase} #{record.number} already has recorded " \
        "results — clear them before moving"
    end
  end

  private def validate_confirmed_lineups!(impacted)
    message = self.class.confirmation_message(impacted)
    raise NeedsConfirmation, message if message
  end

  private def waiting_entry!(key)
    entry = BracketWaitingEntries.for(category).detect { |candidate| candidate.key == key }
    return entry if entry

    raise InvalidMove, "#{key} is not waiting to be placed — reload and try again"
  end
end
