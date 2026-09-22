# frozen_string_literal: true

# The admin write affordances a bracket view hangs off a slot: the drag grip,
# the drop data, and the "Move to…" options that are the keyboard path for every
# gesture. Shared by both trees and by the waiting panel.
#
# Beside BracketLayout rather than inside it. BracketLayout is pure geometry
# over a three-method includer contract — round, position, parents — and says
# so; this is writes, eligibility and freeze rules, which is a different
# question about the same nodes.
#
# Includers define:
#   category          the TeamCategory / IndividualCategory
#   admin?            whether this render is an admin one
#   bracket_records   the loaded nodes (parents preloaded)
#   node_label(node)  "Encounter 4" / "Fight 4" / "Bye"
#   slot_url(node, slot)
module BracketDragAffordances
  extend ActiveSupport::Concern

  # Empty for a frozen bracket as well as for a public render (R3): a move is a
  # draw correction, and the guard refuses it once the tree is settled. Every
  # helper below splats or short-circuits off this, so an empty pair is all it
  # takes to make the whole tree inert.
  #
  # Reads #bracket_frozen? directly rather than through
  # FreezeHelper#bracket_structure_editable?, which is the same negation: this
  # is a question about records, and going through `helpers` would make it
  # answerable only from inside a render.
  def slot_eligibility
    @slot_eligibility ||= if admin? && !category.bracket_frozen?
      BracketSlotMove.eligibility(bracket_records)
    else
      BracketSlotMove::Eligibility.new(sources: Set.new, targets: Set.new)
    end
  end

  def slot_source?(node, slot) = slot_eligibility.sources.include?([node.id, slot])

  def slot_target?(node, slot) = slot_eligibility.targets.include?([node.id, slot])

  # Drop wiring for one slot. Empty for a slot that cannot receive, so a
  # template can splat it unconditionally and an ineligible slot is inert.
  #
  # entry_key is sent back as expected_entry and is deliberately "" for an empty
  # slot: "I believe this is empty" is a belief the server can refuse, where
  # "no belief" is not.
  def slot_data(node, slot)
    return {} unless slot_target?(node, slot)

    {
      slot_id: "#{node.id}-#{slot}",
      entry_key: node.slot_entry(slot)&.key.to_s,
      slot_url: slot_url(node, slot),
      action: "dragover->bracket-slot#dragOver dragleave->bracket-slot#dragLeave drop->bracket-slot#drop"
    }
  end

  def grip_data
    {action: "dragstart->bracket-slot#dragStart dragend->bracket-slot#dragEnd"}
  end

  # The non-drag path: every destination this entry may go to, as
  # [label, "<verb>:<url>", expected_entry_of_the_destination].
  #
  # Slots in its OWN unit are left out — exchanging a unit's two sides only
  # flips which is slot 1 — and "Remove from bracket" appears only while the
  # unit would keep an entry, which is the rule BracketSlotMove refuses on.
  #
  # The expected key rides on the option because a select has no drop element
  # to read it from, and without it the keyboard path would silently overwrite
  # whoever someone else had just put there.
  def move_options(node, slot)
    options = target_options
      .reject { |(node_id, _label, _url, _expected)| node_id == node.id }
      .map { |(_node_id, label, url, expected)| [label, "place:#{url}", expected] }

    if node.slot_occupied?(other_slot(slot))
      options << ["Remove from bracket", "remove:#{slot_url(node, slot)}", node.slot_entry(slot)&.key.to_s]
    end
    options
  end

  # The waiting panel's half of the same question: where may THIS entry land?
  # The answer does not depend on the entry, which is why it is the memoized
  # list below with the verb left off.
  def placement_options
    target_options.map { |(_node_id, label, url, expected)| [label, url, expected] }
  end

  def entry_label(entry) = entry.label

  # A bye's empty side: the one its occupant is NOT in. Here rather than in each
  # tree, because "the other slot" is one question and both trees ask it.
  def empty_slot_of(node) = other_slot(node.bye_slot)

  # Every destination, as [node_id, label, url, expected_entry], built ONCE per
  # render. The tree asks for it at every source slot and the waiting panel at
  # every waiting row; rebuilding it each time made a render quadratic in the
  # number of slots, and each rebuilt option re-read a slot entry.
  private def target_options
    @target_options ||= slot_eligibility.targets.sort.map do |(node_id, slot)|
      node = bracket_records_by_id[node_id]
      [node_id, option_label(node, slot), slot_url(node, slot), node.slot_entry(slot)&.key.to_s]
    end
  end

  # BracketDisplayNumbering skips byes, so #node_label has nothing to call one
  # but "Bye" — and an empty bye side then reads "Bye · empty" on every bye in
  # the draw. Name it by the entry on its other side, which is the only thing
  # that tells two of them apart, or the select (the keyboard and touch path)
  # offers a row of identical options.
  private def option_label(node, slot)
    entry = node.slot_entry(slot)
    return "#{node_label(node)} · #{entry_label(entry)}" if entry

    partner = node.slot_entry(other_slot(slot))
    return "#{node_label(node)} · empty" if partner.nil?

    "#{node_label(node)} (#{entry_label(partner)}) · empty"
  end

  private def other_slot(slot) = (slot == 1) ? 2 : 1

  private def bracket_records_by_id
    @bracket_records_by_id ||= bracket_records.index_by(&:id)
  end
end
