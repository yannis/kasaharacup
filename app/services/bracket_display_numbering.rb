# frozen_string_literal: true

# Assigns each bracket fight a display number: a secondary, viewer-facing
# numbering distinct from the canonical `number`. BYE fights are skipped (they
# are never contested), and real matches are numbered to the highest round
# possible — a parent (later round) is numbered as soon as both of its feeder
# subtrees are exhausted. This is a post-order depth-first traversal of the
# tree rooted at the final, so the resulting order matches how the matches will
# actually be fought.
#
# Returns a Hash of { fight_id => display_number }; BYE fights are absent.
class BracketDisplayNumbering
  def self.for(fights)
    new(fights).numbers
  end

  def initialize(fights)
    @fights = fights
  end

  def numbers
    @numbers = {}
    @counter = 0
    root_fights.each { |fight| assign(fight) }
    @numbers
  end

  private attr_reader :fights

  private def assign(fight)
    return if fight.nil?

    assign(fight.parent_fight_1)
    assign(fight.parent_fight_2)
    return if fight.bye?

    @counter += 1
    @numbers[fight.id] = @counter
  end

  # The roots are the fights no other fight feeds into — a complete bracket has
  # exactly one (the final). Sorted so disconnected trees number top-to-bottom.
  private def root_fights
    parent_ids = fights.flat_map { |fight|
      [fight.parent_fight_1_id, fight.parent_fight_2_id]
    }.compact.to_set
    fights.reject { |fight| parent_ids.include?(fight.id) }
      .sort_by { |fight| [fight.round.to_i, fight.position.to_i] }
  end
end
