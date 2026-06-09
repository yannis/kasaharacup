# frozen_string_literal: true

# Shared SVG bracket layout: card positions, canvas size, and connector paths for
# a single-elimination tree, plus the visibility rules that hide forecasted/pass-
# through nodes. Pure geometry — depends only on each node's round/position/bye?
# and the parent links. Includers must define:
#   bracket_nodes               -> Array of nodes (parents preloaded)
#   node_parents(node)          -> [parent_or_nil, parent_or_nil]
#   node_has_own_identity?(node)-> Boolean (renders even with no resolved child)
module BracketLayout
  extend ActiveSupport::Concern

  CARD_WIDTH = 224
  CARD_HEIGHT = 80
  BYE_CARD_HEIGHT = 40
  ROUND_GAP = 48
  MATCH_GAP = 8
  PADDING = 8

  def rounds
    @rounds ||= bracket_nodes.group_by(&:round)
  end

  def canvas_width
    return 0 if rounds.empty?

    BracketLayout::PADDING * 2 + rounds.keys.max * BracketLayout::CARD_WIDTH +
      (rounds.keys.max - 1) * BracketLayout::ROUND_GAP
  end

  def canvas_height
    return 0 if rounds.empty?

    BracketLayout::PADDING * 2 + first_round_slots * (BracketLayout::CARD_HEIGHT + BracketLayout::MATCH_GAP) -
      BracketLayout::MATCH_GAP
  end

  def first_round_slots
    [rounds.fetch(1, []).size, 1].max
  end

  def match_style(node)
    "left: #{match_left(node)}px; top: #{match_top(node)}px;"
  end

  def match_left(node)
    BracketLayout::PADDING + (node.round - 1) * (BracketLayout::CARD_WIDTH + BracketLayout::ROUND_GAP)
  end

  def match_top(node)
    height = node.bye? ? BracketLayout::BYE_CARD_HEIGHT : BracketLayout::CARD_HEIGHT
    BracketLayout::PADDING + (node_center_y(node) - height / 2.0).round
  end

  def node_center_y(node)
    slot_height = BracketLayout::CARD_HEIGHT + BracketLayout::MATCH_GAP
    span = 2**(node.round - 1)
    first_slot = (node.position - 1) * span

    slot_height * (first_slot + (span / 2.0)) - BracketLayout::MATCH_GAP / 2.0
  end

  def connector_paths
    rounds.values.flatten.filter_map do |node|
      next unless render_node?(node)

      parent_paths(node)
    end.flatten
  end

  def render_node?(node)
    rendered_node_ids.fetch(node.id) do
      rendered_node_ids[node.id] = node_has_own_identity?(node) || render_forecasted_node?(node)
    end
  end

  private def parent_paths(node)
    connector_parents(node).map { |parent| connector_path(parent, node) }
  end

  private def connector_parents(node)
    node_parents(node).compact.flat_map { |parent| visible_connector_parent(parent) }
  end

  private def visible_connector_parent(node)
    return [node] if render_node?(node)
    return connector_parents(node) if hidden_pass_through_node?(node)

    []
  end

  private def connector_path(parent_node, node)
    start_x = match_left(parent_node) + BracketLayout::CARD_WIDTH
    start_y = BracketLayout::PADDING + node_center_y(parent_node).round
    end_x = match_left(node)
    end_y = BracketLayout::PADDING + node_center_y(node).round
    elbow_x = start_x + (end_x - start_x) / 2

    "M #{start_x} #{start_y} H #{elbow_x} V #{end_y} H #{end_x}"
  end

  private def rendered_node_ids
    @rendered_node_ids ||= {}
  end

  private def render_forecasted_node?(node)
    parents = node_parents(node).compact
    parents.any? &&
      parents.any? { |parent| render_node?(parent) } &&
      !hidden_pass_through_node?(node)
  end

  private def hidden_pass_through_node?(node)
    pass_through_node?(node) && child_nodes.fetch(node.id, []).any?
  end

  private def pass_through_node?(node)
    parents = node_parents(node).compact
    return false unless parents.size > 1

    parents.one? { |parent| render_node?(parent) } &&
      parents.any? { |parent| !render_node?(parent) }
  end

  private def child_nodes
    @child_nodes ||= rounds.values.flatten.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |node, children|
      node_parents(node).compact.each { |parent| children[parent.id] << node }
    end
  end
end
