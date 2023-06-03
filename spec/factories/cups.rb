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
      start = Date.parse(c.start_on.to_s)
      start - 14.days
    }

    header_image do
      image_path = Rails.root.glob("spec/fixtures/images/*.jpg").sample
      Rack::Test::UploadedFile.new(image_path)
    end
  end
end
