# frozen_string_literal: true

module IndividualCategoryHelper
  def pool_dom_id(category, pool_number)
    dom_id(category, "pool_#{pool_number}")
  end
end
