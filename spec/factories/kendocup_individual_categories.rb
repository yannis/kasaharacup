FactoryGirl.define do
  factory :kendocup_individual_category, :class => 'Kendocup::IndividualCategory' do
    association :cup, factory: :kendocup_cup
    name {Faker::Name.last_name}
  end
end
