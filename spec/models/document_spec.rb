# frozen_string_literal: true

require "rails_helper"

RSpec.describe Document do
  let(:document) { build(:document) }

  it { expect(document).to be_valid }
end
