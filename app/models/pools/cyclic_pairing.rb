# frozen_string_literal: true

module Pools
  module CyclicPairing
    module_function def pairs_for(size)
      return [] if size < 2

      positions = (1..size).to_a
      pairs = positions.each_cons(2).to_a
      pairs << [1, size] if size > 2
      pairs.map { |a, b| (a < b) ? [a, b] : [b, a] }
    end
  end
end
