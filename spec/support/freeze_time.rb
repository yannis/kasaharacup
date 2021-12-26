# frozen_string_literal: true

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers

  config.around(:each, :freeze_time) do |example|
    travel_to(Time.current) do
      example.run
    end
  end
end
