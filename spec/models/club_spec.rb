# frozen_string_literal: true

require "rails_helper"

RSpec.describe Club, type: :model do
  it { is_expected.to have_many :users }
  it { is_expected.to have_many :kenshis }
  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_uniqueness_of :name }
end
