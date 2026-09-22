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
  def slot_eligibility
    @slot_eligibility ||= if admin? && helpers.bracket_structure_editable?(category)
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
    options = slot_eligibility.targets
      .reject { |(node_id, _)| node_id == node.id }
      .sort
      .map { |(node_id, target_slot)| place_option(node_id, target_slot) }

    if node.slot_occupied?(other_slot(slot))
      options << ["Remove from bracket", "remove:#{slot_url(node, slot)}", node.slot_entry(slot)&.key.to_s]
    end
    options
  end

  # The waiting panel's half of the same question: where may THIS entry land?
  def placement_options
    slot_eligibility.targets.sort.map do |(node_id, slot)|
      node = bracket_records_by_id[node_id]
      [option_label(node, slot), slot_url(node, slot), node.slot_entry(slot)&.key.to_s]
    end
  end

  def entry_label(entry) = entry.label

  private def place_option(node_id, slot)
    node = bracket_records_by_id[node_id]
    [option_label(node, slot), "place:#{slot_url(node, slot)}", node.slot_entry(slot)&.key.to_s]
  end

  private def option_label(node, slot)
    entry = node.slot_entry(slot)
    "#{node_label(node)} · #{entry ? entry_label(entry) : "empty"}"
  end

  private def other_slot(slot) = (slot == 1) ? 2 : 1

  private def bracket_records_by_id
    @bracket_records_by_id ||= bracket_records.index_by(&:id)
  end
end
