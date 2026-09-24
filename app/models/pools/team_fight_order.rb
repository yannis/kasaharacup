# frozen_string_literal: true

module Pools
  # The order a team pool's ties are fought in, and the side each team takes.
  # The pairs are CyclicPairing's, fought in the classical order of the pool
  # positions — 1 <> 2, 1 <> 3, 2 <> 3 — rather than in the order the cycle
  # lists them.
  #
  # Sides follow two rules: a team that fought the tie before keeps its side,
  # so it does not change colour between two ties in a row; otherwise the lower
  # position is red, so the pool's first team starts on the red side.
  module TeamFightOrder
    # [[white, red], ...] in fighting order, as pool positions.
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
