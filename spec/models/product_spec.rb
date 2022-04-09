# frozen_string_literal: true

require "rails_helper"

RSpec.describe Product, type: :model do
  let(:product) { build(:product) }

  it { expect(product).to have_many(:purchases).dependent(:destroy) }
  it { expect(product).to have_many(:kenshis).through(:purchases) }

  it { expect(product).to belong_to :cup }
  it { expect(product).to belong_to(:event).optional }

  it { expect(product).to respond_to :name_en }
  it { expect(product).to respond_to :name_fr }
  it { expect(product).to respond_to :description_en }
  it { expect(product).to respond_to :description_fr }
  it { expect(product).to respond_to :fee_chf }
  it { expect(product).to respond_to :fee_eu }
  it { expect(product).to respond_to :year }

  it { expect(product).to validate_presence_of :name_en }
  it { expect(product).to validate_presence_of :name_fr }
  it { expect(product).to validate_presence_of :fee_chf }
  it { expect(product).to validate_presence_of :fee_eu }

  it { expect(product).to validate_uniqueness_of(:name_en).scoped_to(:cup_id) }
  it { expect(product).to validate_uniqueness_of(:name_fr).scoped_to(:cup_id) }

  it { expect(product).to validate_numericality_of(:fee_chf) }
  it { expect(product).to validate_numericality_of(:fee_eu) }
end
