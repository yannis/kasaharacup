FactoryGirl.define do
  factory :kendocup_participation, :class => 'Kendocup::Participation' do
    association :category, factory: :kendocup_individual_category
    association :kenshi, factory: :kendocup_kenshi
  end
end
