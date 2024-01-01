# frozen_string_literal: true

require "rails_helper"

describe KenshiForm do
  let(:cup) { create(:cup) }
  let(:user) { create(:user) }
  let(:kenshi) { Kenshi.new }
  let(:kenshi_form) { described_class.new(cup: cup, user: user, kenshi: kenshi) }

  describe "#save" do
    before do
      kenshi_form.save(params)
    end

    context "when the kenshi is valid" do
      let(:params) do
        {
          kenshi: {
            female: false,
            first_name: Faker::Name.first_name,
            last_name: Faker::Name.last_name,
            dob: Faker::Date.birthday(min_age: 18, max_age: 65),
            club_name: Faker::Company.name,
            grade: Kenshi::GRADES.sample
          }
        }
      end

      it do
        expect(kenshi_form).to be_valid
      end
    end
  end
end
