require 'faker'
FactoryGirl.define do

  sequence(:integer) { |n| n }

  factory :kendocup_event, :class => 'Kendocup::Event' do
    association :cup, factory: :kendocup_cup
    name_en {Faker::Name.last_name}
    name_fr {Faker::Name.last_name}
    name_de {Faker::Name.last_name}
    start_on {|e| e.cup.start_on.to_time+generate(:integer).hours}
  end
end
