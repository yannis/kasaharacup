# frozen_string_literal: true

class Tree
  attr_accessor :category, :number_of_matches

  def initialize(category)
    @category = category
  end

  def elements
    elements = []
    # if category == Team
    #   elements = Team.all.map(&:name)
    # elsif category.pools.present?
    if category.pools.present?
      out_of_pool = category.out_of_pool
      category.pools.each do |pool|
        out_of_pool.times do |i|
          elements << "pool#{pool.number}.#{i + 1}"
        end
      end
    end
    elements.shuffle
  end

  def branch_number
    branch_number = if elements.first.is_a? Pool
      elements.size * category.out_of_pool
    else
      elements.size
    end
    modulo = branch_number % 4
    if modulo > 0
      branch_number += (4 - modulo)
    end
    branch_number
  end

  def depth
    branch_number > 0 ? Math.log2(branch_number).to_i : 0
  end

  def fight_number
    branch_number - 1
  end
end
