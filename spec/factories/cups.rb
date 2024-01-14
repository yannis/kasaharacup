# frozen_string_literal: true

FactoryBot.define do
  sequence(:year) { |n| Date.current.year + n }
  factory :cup do
    start_on {
      if (max_start_on = Cup.maximum(:start_on))
        max_start_on + 1.year
      else
        generate(:year).to_s + "-11-29"
      end
    }
    deadline { |c|
      return nil if c.start_on.blank?

      start = c.start_on.is_a?(String) ? Date.parse(c.start_on) : c.start_on
      start - 14.days
    }

    header_image do
      image_path = Rails.root.glob("spec/fixtures/images/*.jpg").sample
      Rack::Test::UploadedFile.new(image_path)
    end

    trait :with_cup_products do
      product_individual_junior { association(:product) }
      product_individual_adult { association(:product) }
      product_team { association(:product) }
      product_full_junior { association(:product) }
      product_full_adult { association(:product) }
    end
  end
end
