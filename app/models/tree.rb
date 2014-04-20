class Tree

  attr_accessor :category, :elements, :branch_number, :number_of_matches, :depth

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
      for pool in category.pools
        out_of_pool.times do |i|
          elements << "pool#{pool.number}.#{i+1}"
        end
      end
    end
    return elements.shuffle
  end

  def branch_number
    if elements.first.is_a? Pool
      branch_number = elements.size*category.out_of_pool
    else
      branch_number = elements.size
    end
    modulo = branch_number % 4
    if modulo > 0
      branch_number = branch_number+(4-modulo)
    end
    return branch_number
  end

  def depth
    branch_number > 0 ? Math.log2(branch_number).to_i : 0
  end

  def fight_number
    branch_number-1
  end
end
