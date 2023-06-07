# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    name { Faker::File.file_name(ext: "pdf") }
    category factory: %i[individual_category]
    file { Rack::Test::UploadedFile.new("spec/fixtures/test.pdf", "application/pdf") }
  end
end
