Cup.destroy_all
cup = Cup.find_or_create_by start_on: "2014-09-27"

Club.destroy_all
clubs_data = [
  {name: "SDK Genève"},
  {name: "Budokan Lausanne"},
  {name: "Hokkaidō Police Dojo"}
]
clubs_data.each do |c|
  Club.create! c
end

User.destroy_all
users_data = [
  {
    first_name: "Yannis",
    last_name: "Jaquet",
    email: "suvar3_7@mac.com",
    club_id: Club.find_by(name: "SDK Genève"),
    password: "12345678",
    password_confirmation: "12345678"
  },
  {
    first_name: "Naoki",
    last_name: "Eiga",
    email: "bidon@kasaharacup.com",
    club_id: Club.find_by(name: "Hokkaidō Police Dojo"),
    password: "12345678",
    password_confirmation: "12345678"
  }
]
users_data.each do |c|
  User.create! c
end
User.all.each(&:confirm!)

cup.events.destroy_all
events_data = [
  {
    name_en: "Kyu Examinations (for Swiss Kendo Federation members only)",
    name_fr: "Examens de Kyu (seulement pour les licenciés suisses)",
    start_on: '2014-09-27 09:30'
  },
  {
    name_en: "Check-in and shinais check",
    name_fr: "Accueil et contôle des shinais",
    start_on: '2014-09-27 12:00'
  },
  {
    name_en: "Team competition",
    name_fr: "Compétition par équipe",
    start_on: '2014-09-27 13:00'
  },
  {
    name_en: "Free jigeiko",
    name_fr: "Jigeiko libre",
    start_on: '2014-09-27 18:00'
  },
  {
    name_en: "Dinner",
    name_fr: "Dîner",
    start_on: '2014-09-27 20:00'
  },
  {
    name_en: "Breakfast",
    name_fr: "Petit-déjeuner",
    start_on: '2014-09-28 07:00'
  },
  {
    name_en: "Individual competition (open, ladies and juniors)",
    name_fr: "Compétition en individuel (open, ladies et juniors)",
    start_on: '2014-09-28 08:30'
  },
  {
    name_en: "Lunch break",
    name_fr: "Pause déjeuner",
    start_on: '2014-09-28 12:00'
  },
  {
    name_en: "Finals and ending",
    name_fr: "Finales et clôture",
    start_on: '2014-09-28 17:00'
  }
]
events_data.each do |e|
  Event.create! e.merge!(cup: cup)
end

cup.products.destroy_all
products_data = [
  {
    name_en: "Dinner",
    name_fr: "Dîner",
    fee_chf: 25,
    fee_eu: 20,
    event: Event.where(name_en: "Dinner").first
  },
  {
    name_en: "Night at the dormitory",
    name_fr: "Nuit au dortoir",
    fee_chf: 25,
    fee_eu: 20
  }
]
products_data.each do |e|
  Product.create! e.merge!(cup: cup)
end

cup.individual_categories.destroy_all
individual_categories_data = [
  {
    name: "open",
    pool_size: 3,
    out_of_pool: 2,
    min_age: 16,
    description_en: "5 fighters over 16 years old",
    description_fr: "plus de 16 ans",
    cup: cup
  },
  {
    name: "ladies",
    pool_size: 3,
    out_of_pool: 2,
    min_age: 16,
    description_en: "over 16 years old",
    description_fr: "plus de 16 ans",
    cup: cup
  },
  {
    name: "juniors",
    pool_size: 3,
    out_of_pool: 2,
    min_age: 12,
    max_age: 15,
    description_en: "from 12 to 16 years old",
    description_fr: "12 à 16 ans",
    cup: cup
  }
]
individual_categories_data.each do |c|
  IndividualCategory.create! c
end

cup.team_categories.destroy_all
team_categories_data = [
  {
    name: "team",
    pool_size: nil,
    out_of_pool: nil,
    min_age: 16,
    description_en: "from 12 to 16 years old",
    description_fr: "12 à 16 ans",
    cup: cup
  }
]
team_categories_data.each do |c|
  TeamCategory.create! c
end
