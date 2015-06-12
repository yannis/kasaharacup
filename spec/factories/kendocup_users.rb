FactoryGirl.define do
  factory :kendocup_user, class: 'User' do
    first_name { Faker::Name.first_name}
    last_name { Faker::Name.last_name}
    email {Faker::Internet.email}
    password { Faker::Internet.password(8) }
    # password_confirmation {|a| a.password}
    confirmed_at {Time.current}
  end
end
