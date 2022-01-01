# frozen_string_literal: true

require "rails_helper"

describe "temporary:cups:add_2022" do
  describe "add_units" do
    it do
      expect { Rake::Task["temporary:cups:add_2022"].invoke }
        .to change(Cup, :count).by(1)
        .and(change(Event, :count).by(9))
        .and(change(Product, :count).by(3))
        .and(change(IndividualCategory, :count).by(5))
        .and(change(TeamCategory, :count).by(1))
    end
  end
end
