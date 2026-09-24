# frozen_string_literal: true

module Pools
  # The order a pool's fights are fought in, and the side each fighter takes —
  # team ties and individual fights alike. The pairs are CyclicPairing's,
  # fought in the classical order of the pool positions — 1 <> 2, 1 <> 3,
  # 2 <> 3 — rather than in the order the cycle lists them.
  #
  # Sides follow two rules: a fighter that fought the bout before keeps its
  # side, so it does not change colour between two bouts in a row; otherwise
  # the lower position is red, so the pool's first fighter starts on the red
  # side.
  #
  # Which column holds which colour differs by kind: an encounter's team_1 is
  # white (TeamMatchSheet), a fight's fighter_1 red (the tinted side of the
  # pool card).
  module FightOrder
    # [[white, red], ...] in fighting order, as positions in the pool (1-based).
    module_function def sides_for(size)
      previous = {}
      CyclicPairing.pairs_for(size).map(&:minmax).sort.map do |low, high|
        red, white = (previous[high] == :red || previous[low] == :white) ? [high, low] : [low, high]
        previous = {red => :red, white => :white}
        [white, red]
      end
    end
  end
end
