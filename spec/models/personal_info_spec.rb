# frozen_string_literal: true

require "rails_helper"

describe(PersonalInfo) do
  describe("Associations") do
    let(:personal_info) { create(:personal_info) }

    it { expect(personal_info).to(belong_to(:kenshi).inverse_of(:personal_info)) }
  end

  describe "Enums" do
    describe "document_types" do
      it do
        expect(build(:personal_info)).to define_enum_for(:document_type)
          .with_values(passport: "passport", id_card: "id_card")
          .backed_by_column_of_type(:enum)
      end
    end
  end

  describe "Validations" do
    let(:personal_info) { build(:personal_info, email: email) }
    let(:email) { Faker::Internet.email }

    describe "residential_phone_number" do
      it { expect(personal_info).to validate_presence_of(:residential_phone_number) }
    end

    describe "residential_address" do
      it { expect(personal_info).to validate_presence_of(:residential_address) }
    end

    describe "residential_zip_code" do
      it { expect(personal_info).to validate_presence_of(:residential_zip_code) }
    end

    describe "residential_city" do
      it { expect(personal_info).to validate_presence_of(:residential_city) }
    end

    describe "residential_country" do
      it do
        expect(personal_info).to validate_presence_of(:residential_country)
        expect(personal_info)
          .to(
            validate_inclusion_of(:residential_country).in_array(ISO3166::Country.all.map(&:alpha2))
          )
      end
    end

    describe "origin_country" do
      it do
        expect(personal_info)
          .to(validate_inclusion_of(:origin_country).in_array(ISO3166::Country.all.map(&:alpha2)))
      end
    end

    describe "document_type" do
      it do
        expect(personal_info).to validate_presence_of(:document_type)
      end
    end

    describe "document_number" do
      it { expect(personal_info).to validate_presence_of(:document_number) }
    end

    describe "email" do
      it { expect(personal_info).to validate_presence_of(:email) }

      context "when email is valid" do
        let(:email) { Faker::Internet.email }

        it do
          expect(personal_info).to be_valid
        end
      end

      context "when email is invalid" do
        let(:email) { "invalid_email" }

        it do
          expect(personal_info).not_to be_valid
          expect(personal_info.errors[:email]).to include("n'est pas valide")
        end
      end
    end
  end
end
