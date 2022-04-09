# frozen_string_literal: true

require "rails_helper"

RSpec.describe Club, type: :model do
  let(:club) { create(:club) }

  it do
    expect(club).to have_many :users
    expect(club).to have_many :kenshis
    expect(club).to validate_presence_of :name
    expect(club).to validate_uniqueness_of :name
  end
end
