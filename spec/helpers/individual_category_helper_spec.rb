# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndividualCategoryHelper do
  describe "#pool_dom_id" do
    it "encodes the pool number into the dom id" do
      cup = create(:cup)
      category = create(:individual_category, cup: cup)
      expect(helper.pool_dom_id(category, 3)).to eq "pool_3_individual_category_#{category.id}"
    end
  end
end
