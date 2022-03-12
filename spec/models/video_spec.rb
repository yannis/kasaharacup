# frozen_string_literal: true

require "rails_helper"

RSpec.describe Video do
  describe "Associations" do
    let(:video) { build(:video) }

    it { expect(video).to belong_to(:category) }
  end

  describe "Validations" do
    let(:video) { create(:video) }

    it { expect(video).to validate_presence_of(:name) }
    it { expect(video).to validate_uniqueness_of(:name).scoped_to(:category_type, :category_id) }
    it { expect(video).to validate_presence_of(:url) }
    it { expect(video).to validate_uniqueness_of(:url) }
  end
end
