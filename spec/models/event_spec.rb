# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  it { is_expected.to belong_to :cup }

  it { is_expected.to respond_to :name_en }
  it { is_expected.to respond_to :name_fr }
  it { is_expected.to respond_to :name_de }
  it { is_expected.to respond_to :start_on }
  it { is_expected.to respond_to :duration }
  it { is_expected.to respond_to :year }

  describe "Validations" do
    it { is_expected.to validate_presence_of :name_fr }
    it { is_expected.to validate_presence_of :name_en }
    it { is_expected.to validate_presence_of :start_on }
  end

  describe "A event", type: :model do
    let!(:event) { create :event, cup: create(:cup, start_on: Date.parse("2016-09-28")) }

    it { expect(event.year).to be 2016 }
  end
end
