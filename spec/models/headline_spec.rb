# frozen_string_literal: true

require "rails_helper"

RSpec.describe Headline, type: :model do
  it { is_expected.to belong_to :cup }

  it { is_expected.to respond_to :title_en }
  it { is_expected.to respond_to :title_fr }
  it { is_expected.to respond_to :content_en }
  it { is_expected.to respond_to :content_fr }
  it { is_expected.to respond_to :shown }

  it { is_expected.to validate_presence_of :title_en }
  it { is_expected.to validate_presence_of :content_fr }

  describe "An headline shown and a not shown" do
    let(:cup) { create :cup }
    let!(:headline_shown) do
      create :headline, title_fr: "un titre", title_en: "a title", cup: cup, shown: true
    end
    let!(:headline_not_shown) { create :headline, cup: cup, shown: false }

    it { expect(described_class.shown.to_a).to eql [headline_shown] }
    it { expect(headline_shown.to_param).to eql "#{headline_shown.id}-a-title" }
  end
end
