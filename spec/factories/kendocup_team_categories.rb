FactoryGirl.define do
  factory :kendocup_team_category, :class => 'Kendocup::TeamCategory' do
    association :cup, factory: :kendocup_cup
    name {Faker::Name.last_name}
  end
end
