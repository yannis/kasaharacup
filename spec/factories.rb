FactoryGirl.define do

  sequence(:integer) { |n| n }
  factory :cup do
    sequence(:start_on) {|n| "#{n}-09-27"}
  end

  factory :club do
    name { Faker::Company.name }
  end

  factory :event do
    association :cup
    name_en {Faker::Name.last_name}
    name_fr {Faker::Name.last_name}
    start_on {|e| e.cup.start_on.to_time+generate(:integer).hours}
  end

  factory :individual_category do
    association :cup
    name {Faker::Name.last_name}
  end

  factory :team_category do
    association :cup
    name {Faker::Name.last_name}
  end

  factory :fight do
    association :individual_category
    number {|f|
      max_number = f.individual_category.fights.maximum(:number)
      (max_number.presence || 0)+1
    }
    fighter_type "Kenshi"
    fighter_1_id {create(:kenshi).id}
    fighter_2_id {create(:kenshi).id}
  end

  factory :kenshi do
    association :cup
    association :user
    association :club
    first_name { Faker::Name.first_name}
    last_name { Faker::Name.last_name}
    dob {20.years.ago}
    grade 'kyu'
  end

  factory :participation do
    association :category, factory: :individual_category
    association :kenshi
  end

  factory :team do
    name {'team_name_'+Faker::Company.name}
  end

  factory :user do
    first_name { Faker::Name.first_name}
    last_name { Faker::Name.last_name}
    email {Faker::Internet.email}
    password { Faker::Internet.password(8) }
    password_confirmation {|a| a.password}
    confirmed_at {Time.current}
  end
end
