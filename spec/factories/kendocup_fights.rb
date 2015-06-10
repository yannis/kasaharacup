FactoryGirl.define do
  factory :kendocup_fight, :class => 'Kendocup::Fight' do
    association :individual_category, factory: :kendocup_individual_category
    number {|f|
      max_number = f.individual_category.fights.maximum(:number)
      (max_number.presence || 0)+1
    }
    fighter_type "Kenshi"
    fighter_1_id {create(:kenshi).id}
    fighter_2_id {create(:kenshi).id}
  end
end
