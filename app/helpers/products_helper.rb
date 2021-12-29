# frozen_string_literal: true

module ProductsHelper
  def product_available?(product)
    raise WrongObjectType unless product.is_a?(Product)
    return false if product.name_en.downcase.include?("dormitory") && product.purchases.count > 49
    true
  end
end
