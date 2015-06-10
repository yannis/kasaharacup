require 'faker'
FactoryGirl.define do
  factory :kendocup_purchase, :class => 'Kendocup::Purchase' do
    association :product, factory: :kendocup_product
    association :kenshi, factory: :kendocup_kenshi
  end
end
