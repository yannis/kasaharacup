# frozen_string_literal: true

require "rails_helper"

describe "temporary:cups:add_2023" do # rubocop:disable RSpec/DescribeClass
  before { create(:cup, start_on: Date.new(2023, 9, 23)) }

  it do
    expect { Rake::Task["temporary:cups:add_2023"].invoke }
      .to change(Event, :count).by(9)
      .and(not_change(Cup, :count))
      .and(change(Product, :count).by(9))
      .and(change(IndividualCategory, :count).by(4))
      .and(change(TeamCategory, :count).by(1))
  end
end
