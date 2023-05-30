# frozen_string_literal: true

require "rails_helper"

RSpec.describe Club do
  let(:club) { create(:club) }

  describe "Associations" do
    it do
      expect(club).to have_many :users
      expect(club).to have_many :kenshis
      expect(club).to validate_presence_of :name
      expect(club).to validate_uniqueness_of :name
    end
  end

  describe "#to_s" do
    let(:club) { build(:club, name: "a fantastic club") }

    it { expect(club.to_s).to eql "a fantastic club" }
  end
end
