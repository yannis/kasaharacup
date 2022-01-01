# frozen_string_literal: true

require "rails_helper"

RSpec.describe Product, type: :model do
  it { is_expected.to have_many(:purchases).dependent(:destroy) }
  it { is_expected.to have_many(:kenshis).through(:purchases) }

  it { is_expected.to belong_to :cup }
  it { is_expected.to belong_to(:event).optional }

  it { is_expected.to respond_to :name_en }
  it { is_expected.to respond_to :name_fr }
  it { is_expected.to respond_to :description_en }
  it { is_expected.to respond_to :description_fr }
  it { is_expected.to respond_to :fee_chf }
  it { is_expected.to respond_to :fee_eu }
  it { is_expected.to respond_to :year }

  it { is_expected.to validate_presence_of :name_en }
  it { is_expected.to validate_presence_of :name_fr }
  it { is_expected.to validate_presence_of :fee_chf }
  it { is_expected.to validate_presence_of :fee_eu }

  it { is_expected.to validate_uniqueness_of(:name_en).scoped_to(:cup_id) }
  it { is_expected.to validate_uniqueness_of(:name_fr).scoped_to(:cup_id) }

  it { is_expected.to validate_numericality_of(:fee_chf) }
  it { is_expected.to validate_numericality_of(:fee_eu) }
end
