FactoryGirl.define do
  factory :kendocup_team, class: 'Kendocup::Team' do
    name {'team_name_'+Faker::Company.name}
    association :team_category, factory: :kendocup_team_category
  end
end
