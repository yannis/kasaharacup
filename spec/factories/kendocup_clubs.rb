require 'faker'
FactoryGirl.define do
  factory :kendocup_club, :class => 'Kendocup::Club' do
    name { Faker::Company.name }
  end
end
