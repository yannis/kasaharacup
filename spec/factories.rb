FactoryGirl.define do

  sequence(:integer) { |n| n }
  factory :cup do
    start_on {rand(Date.civil(2000, 1, 1)..Date.civil(Date.current.year, 12, 31))}
    deadline {|c|
      return nil if c.start_on.blank?
      start = Date.parse(c.start_on.to_s)
      start-14.days
    }
    adult_fees_chf {30}
    adult_fees_eur {25}
    junior_fees_chf {16}
    junior_fees_eur {14}
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
    association :cup, start_on: "#{Date.current.year}-11-30"
    association :user
    association :club
    female {false}
    first_name { Faker::Name.first_name}
    last_name { Faker::Name.last_name}
    dob {"1990-01-01"}
    grade 'kyu'
  end

  factory :participation do
    association :category, factory: :individual_category
    association :kenshi
  end

  factory :purchase do
    association :product
    association :kenshi
  end

  factory :product do
    association :cup
    name_en {Faker::Name.last_name}
    name_fr {Faker::Name.last_name}
    fee_chf {10}
    fee_eu {8}
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
