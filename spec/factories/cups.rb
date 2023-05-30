# frozen_string_literal: true

FactoryBot.define do
  factory :cup do
    start_on { rand(Date.civil(Date.current.year + 1, 1, 1)..Date.civil(Date.current.year + 10, 12, 31)) }
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
