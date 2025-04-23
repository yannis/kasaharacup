# frozen_string_literal: true

require "rails_helper"

describe "temporary:cups:add_2025" do # rubocop:disable RSpec/DescribeClass
  it do
    expect { Rake::Task["temporary:cups:add_2025"].invoke }
      .to change(Cup, :count).by(1)
      .and(change(Event, :count).by(10))
      .and(change(Product, :count).by(7))
      .and(change(IndividualCategory, :count).by(4))
      .and(change(TeamCategory, :count).by(1))
  end
end
