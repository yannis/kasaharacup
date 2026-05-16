# frozen_string_literal: true

module Pools
  module CyclicPairing
    module_function def pairs_for(size)
      return [] if size < 2

      pairs = [[1, 2]]
      return pairs if size == 2

      left, right = 1, 2
      (3..size).each_with_index do |position, i|
        if i.even?
          left = position
        else
          right = position
        end
        pairs << [left, right]
      end
      if size.even?
        left = 1
      else
        right = 1
      end
      pairs << [left, right]
      pairs
    end
  end
end
