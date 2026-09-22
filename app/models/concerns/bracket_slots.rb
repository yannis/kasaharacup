# frozen_string_literal: true

# One interface over the two column families a round-1 bracket slot lives in —
# Encounter's team_N_id / team_N_pool_number / team_N_pool_rank and Fight's
# fighter_N_* — so BracketSlotMove can be written once for both bracket kinds.
#
# BracketDisplayNumbering is the precedent: it serves both record types through
# a small published interface rather than being written twice and drifting.
#
# Includers define:
#   SLOT_PREFIX                   "team" / "fighter"
#   slot_extra_attributes(entry)  columns the competitor id drags along
#                                 (Fight's shared polymorphic fighter_type)
#   invalidate_slot_matchup       discard the stale matchup after a re-resolve
#   refresh_child_slot_from_bye   what a unit owes its child when its bye-ness
#                                 changes (a no-op on Fight)
#   children                      public
# and already answer #bye?, #bye_slot and #unscored?.
module BracketSlots
  extend ActiveSupport::Concern

  SLOTS = [1, 2].freeze

  def slot_entry(slot)
    BracketEntry.for(
      pool_number: self[slot_column(slot, :pool_number)],
      pool_rank: self[slot_column(slot, :pool_rank)],
      competitor: public_send(:"#{self.class::SLOT_PREFIX}_#{slot}")
    )
  end

  # NOT `competitor.present?`. A slot holding a pool label with nobody resolved
  # into it yet is occupied — both models already say exactly this, privately,
  # as #slot_present?, which is what #bye_slot is built on. Read it off the
  # competitor instead and a pooled bracket drawn before the pools finish is a
  # tree of byes.
  def slot_occupied?(slot)
    slot_entry(slot).present?
  end

  def entry_slot_for(key)
    SLOTS.detect { |slot| slot_entry(slot)&.key == key }
  end

  # The one path that writes a bracket slot by hand, and the reason a manual
  # layout survives "Update bracket": it writes the competitor id AND both
  # descriptor columns together, so the next build re-resolves each slot from
  # the label the ADMIN put there.
  #
  # It cannot delegate to Encounter#assign_team_to_slot. That method opens with
  # `return if public_send(column) == team&.id`, which reads true for every
  # move made before the pools have finished — two labels exchanged while both
  # team ids stay nil — and would drop the write on the floor. Nor can it be
  # folded into that method, which is the WINNER-propagation path and must go
  # on treating a slot as an id.
  #
  # Returns true when something changed, false when the slot already held this
  # entry. The caller needs the answer: a descriptor-only write saves no
  # competitor-id change, so neither model's tree broadcast fires and the
  # controller's own broadcast is the only redraw there will be.
  def assign_slot_entry(slot, entry)
    attributes = slot_attributes(slot, entry)
    return false if attributes.all? { |column, value| self[column] == value }

    was_bye = bye?
    previous_competitor_id = self[slot_column(slot, :id)]

    transaction do
      # This is what fires Encounter#propagate_bye_to_children for a unit that
      # STAYS a bye under a new occupant.
      update!(attributes)
      # ...and this is what that callback cannot do. Its guard
      # #bye_occupant_changed? requires bye? to still be true, so it reads false
      # the moment bye-ness flips — in either direction — and false again for a
      # label-only move, which saves no id change for it to see. Either way the
      # child is left holding an occupant seeded at build time that no longer
      # belongs to it.
      refresh_child_slot_from_bye if was_bye != bye?
      invalidate_slot_matchup if previous_competitor_id.present?
    end
    true
  end

  def clear_slot(slot) = assign_slot_entry(slot, nil)

  private def slot_attributes(slot, entry)
    {
      slot_column(slot, :id) => entry&.competitor&.id,
      slot_column(slot, :pool_number) => entry&.pool_number,
      slot_column(slot, :pool_rank) => entry&.pool_rank
    }.merge(entry ? slot_extra_attributes(entry) : {})
  end

  private def slot_column(slot, suffix)
    :"#{self.class::SLOT_PREFIX}_#{slot}_#{suffix}"
  end
end
