FactoryGirl.define do
  factory :kendocup_kenshi, :class => 'Kendocup::Kenshi' do
    association :cup, factory: :kendocup_cup, start_on: "#{Date.current.year}-11-30"
    association :user, factory: :kendocup_user
    association :club, factory: :kendocup_club
    female {false}
    first_name { Faker::Name.first_name}
    last_name { Faker::Name.last_name}
    dob {"1990-01-01"}
    grade 'kyu'
  end
end
