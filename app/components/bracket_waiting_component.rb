# frozen_string_literal: true

# The entries an admin has pulled out of the bracket and not yet put back — the
# counterpart of the unpooled panel beside the pools, and itself the drop zone
# that takes an entry out.
#
# ONE component for both bracket kinds where the pool panels are two
# (TeamPoolUnpooledComponent / IndividualPoolUnpooledComponent), because a
# waiting row is a BracketEntry either way: the label is the entry's, and only
# the name of the competitor behind it differs.
#
# The root always renders, even with nothing waiting, so a Turbo replace always
# has a target — the same rule TeamPoolUnpooledComponent documents.
class BracketWaitingComponent < ViewComponent::Base
  include ActionView::RecordIdentifier
  include BracketDragAffordances

  def self.dom_id_for(category)
    "bracket_waiting_#{ActionView::RecordIdentifier.dom_id(category)}"
  end

  def initialize(category:)
    @category = category
  end

  private attr_reader :category

  # Admin-only by construction — nothing renders this publicly — so the freeze
  # flag alone decides, which is what #slot_eligibility reads.
  private def admin? = true

  private def dom_id_for_waiting = self.class.dom_id_for(category)

  private def entries
    @entries ||= BracketWaitingEntries.for(category)
  end

  private def bracket_records
    @bracket_records ||= BracketSlotMove.bracket_for(category)
  end

  private def editable? = helpers.bracket_structure_editable?(category)

  private def node_label(node)
    return "Bye" if node.bye?

    "#{node.model_name.human} #{display_numbers[node.id]}"
  end

  private def display_numbers
    @display_numbers ||= BracketDisplayNumbering.for(bracket_records)
  end

  # The descriptor, and who is behind it when anyone is: "3.2 · Kendo Club B",
  # or "3.2" alone before the pools have finished. The ONE place the two bracket
  # kinds differ — a kenshi gets their poster name, batched; a team its own —
  # and it is a method rather than a second component.
  private def entry_label(entry)
    name = competitor_name(entry)
    return entry.label if name.blank?
    return name unless entry.descriptor?

    "#{entry.label} · #{name}"
  end

  private def competitor_name(entry)
    return if entry.competitor.nil?
    return entry.competitor.name unless entry.competitor.is_a?(Kenshi)

    poster_names[entry.competitor.id] || entry.competitor.poster_name
  end

  private def poster_names
    @poster_names ||= Kenshi.poster_names_for(
      entries.filter_map { |entry| entry.competitor if entry.competitor.is_a?(Kenshi) }
    )
  end

  private def drop_zone_data
    return {} unless editable?

    {action: "dragover->bracket-slot#dragOverWaiting dragleave->bracket-slot#dragLeaveWaiting " \
             "drop->bracket-slot#dropToWaiting"}
  end

  private def slot_url(node, slot)
    if category.is_a?(TeamCategory)
      helpers.admin_team_category_bracket_slot_path(category, "#{node.id}-#{slot}")
    else
      helpers.admin_individual_category_bracket_slot_path(category, "#{node.id}-#{slot}")
    end
  end
end
