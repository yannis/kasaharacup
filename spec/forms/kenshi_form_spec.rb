# frozen_string_literal: true

require "rails_helper"

describe KenshiForm do
  let(:cup) { create(:cup) }
  let(:user) { create(:user) }
  let(:team_category) { create(:team_category, cup: cup) }
  let(:individual_category) { create(:individual_category, cup: cup) }
  let(:product) { create(:product, cup: cup) }
  let(:kenshi_form) { described_class.new(cup: cup, user: user, kenshi: kenshi) }

  describe "#save" do
    context "when kenshi is a new record" do
      let(:kenshi) { build(:kenshi) }

      context "when params are valid" do
        let(:params) do
          {
            kenshi: {
              female: false,
              first_name: Faker::Name.first_name,
              last_name: Faker::Name.last_name,
              dob: Faker::Date.birthday(min_age: 18, max_age: 65),
              club_name: Faker::Company.name,
              grade: Kenshi::GRADES.sample
            },
            participations: {
              team_category: {
                category_type: "TeamCategory",
                category_id: team_category.id,
                team_name: "Team Name #1"
              },
              individual_category: {
                category_type: "IndividualCategory",
                category_id: individual_category.id,
                save: "1"
              }
            },
            purchases: {
              product: {
                product_id: product.id,
                save: "1"
              }
            }
          }
        end

        it do
          expect { kenshi_form.save(params) }
            .to change(Kenshi, :count).by(1)
            .and not_change(PersonalInfo, :count).from(0)
            .and change(Participation, :count).by(2)
            .and change(Purchase, :count).by(1)
        end
      end

      context "when params are invalid" do
        let(:params) do
          {
            kenshi: {
              female: false,
              first_name: "",
              last_name: Faker::Name.last_name,
              dob: Faker::Date.birthday(min_age: 18, max_age: 65),
              club_name: Faker::Company.name,
              grade: Kenshi::GRADES.sample
            },
            participations: {
              team_category: {
                category_type: "TeamCategory",
                category_id: team_category.id,
                team_name: "Team Name #1"
              },
              individual_category: {
                category_type: "IndividualCategory",
                category_id: individual_category.id,
                save: "1"
              }
            },
            purchases: {
              product: {
                product_id: product.id,
                save: "1"
              }
            }
          }
        end

        it do
          expect { kenshi_form.save(params) }
            .to not_change(Kenshi, :count).from(0)
            .and not_change(PersonalInfo, :count).from(0)
            .and not_change(Participation, :count).from(0)
            .and not_change(Purchase, :count).from(0)
          expect(kenshi_form.errors.full_messages).to eq ["Kenshi: Prénom ne peut pas rester vide"]
          expect(kenshi_form.kenshi.errors.full_messages).to eq ["Prénom ne peut pas rester vide"]
        end
      end
    end

    context "when kenshi is a persisted record" do
      let!(:kenshi) { create(:kenshi, cup: cup, user: user) }

      context "when params are valid" do
        let(:params) do
          {
            kenshi: {
              female: false,
              first_name: Faker::Name.first_name,
              last_name: Faker::Name.last_name,
              dob: Faker::Date.birthday(min_age: 18, max_age: 65),
              club_name: Faker::Company.name,
              grade: Kenshi::GRADES.sample
            },
            participations: {
              team_category: {
                category_type: "TeamCategory",
                category_id: team_category.id,
                team_name: "Team Name #1"
              },
              individual_category: {
                category_type: "IndividualCategory",
                category_id: individual_category.id,
                save: "1"
              }
            },
            purchases: {
              product: {
                product_id: product.id,
                save: "1"
              }
            }
          }
        end

        it do
          expect { kenshi_form.save(params) }
            .to not_change(Kenshi, :count).from(1)
            .and not_change(PersonalInfo, :count).from(0)
            .and change(Participation, :count).by(2)
            .and change(Purchase, :count).by(1)
        end
      end

      context "when params are invalid" do
        let(:params) do
          {
            kenshi: {
              female: false,
              first_name: "",
              last_name: Faker::Name.last_name,
              dob: Faker::Date.birthday(min_age: 18, max_age: 65),
              club_name: Faker::Company.name,
              grade: Kenshi::GRADES.sample
            },
            participations: {
              team_category: {
                category_type: "TeamCategory",
                category_id: team_category.id,
                team_name: "Team Name #1"
              },
              individual_category: {
                category_type: "IndividualCategory",
                category_id: individual_category.id,
                save: "1"
              }
            },
            purchases: {
              product: {
                product_id: product.id,
                save: "1"
              }
            }
          }
        end

        it do
          expect { kenshi_form.save(params) }
            .to not_change(Kenshi, :count).from(1)
            .and not_change(PersonalInfo, :count).from(0)
            .and not_change(Participation, :count).from(0)
            .and not_change(Purchase, :count).from(0)
          expect(kenshi_form.errors.full_messages).to eq ["Kenshi: Prénom ne peut pas rester vide"]
          expect(kenshi_form.kenshi.errors.full_messages).to eq ["Prénom ne peut pas rester vide"]
        end
      end
    end
  end
end
