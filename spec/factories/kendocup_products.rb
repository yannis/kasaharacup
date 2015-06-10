require 'faker'
FactoryGirl.define do
  factory :kendocup_product, :class => 'Kendocup::Product' do
    association :cup, factory: :kendocup_cup
    name_en {Faker::Name.last_name}
    name_fr {Faker::Name.last_name}
    fee_chf {10}
    fee_eu {8}
  end
end
