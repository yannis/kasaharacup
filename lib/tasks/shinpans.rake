namespace :shinpans do
  namespace :development do
    desc "export for individual category"
    task :export_for_individual_category, [:category_id]  => [:environment] do |task, args|
      raise "Environment is not 'development'" unless Rails.env.development?
      category_id = args[:category_id]
      cup = Kendocup::Cup.last
      category = Kendocup::IndividualCategory.find(category_id)
      participations = category.participations
      kenshis = Kendocup::Kenshi.includes(:club)
                                .joins(:participations)
                                .merge(participations)
                                .where(cup: cup, grade: ["4Dan", "5Dan", "6Dan", "7Dan"])

      path = Rails.root.join("tmp", "#{category.name}_shinpans.csv")
      out_file = File.new(path, "w")

      out_file.puts ["Last name", "First name", "Grade", "Club", "Gender", "DOB", "Pool"].join(", ")
      kenshis.order(last_name: :asc).find_each do |kenshi|
        out_file.puts [
          kenshi.last_name,
          kenshi.first_name,
          kenshi.grade,
          kenshi.club.name,
          kenshi.female? ? "F" : "M",
          kenshi.dob,
          participations.find_by(kenshi_id: kenshi.id).pool_number
        ].map { |s| s.to_s.gsub(",", " -") }.join(", ")
      end

      out_file.close
    end

    desc "export for team category"
    task :export_for_team_category, [:category_id]  => [:environment] do |task, args|
      raise "Environment is not 'development'" unless Rails.env.development?
      category_id = args[:category_id]
      cup = Kendocup::Cup.last
      category = Kendocup::TeamCategory.find(category_id)
      participations = category.participations
      kenshis = Kendocup::Kenshi.includes(:club)
                                .joins(:participations)
                                .merge(participations)
                                .where(cup: cup, grade: ["4Dan", "5Dan", "6Dan", "7Dan"])

      path = Rails.root.join("tmp", "#{category.name}_shinpans.csv")
      out_file = File.new(path, "w")

      out_file.puts ["Last name", "First name", "Grade", "Club", "Gender", "DOB", "Team"].join(", ")
      kenshis.order(last_name: :asc).find_each do |kenshi|
        out_file.puts [
          kenshi.last_name,
          kenshi.first_name,
          kenshi.grade,
          kenshi.club.name,
          kenshi.female? ? "F" : "M",
          kenshi.dob,
          participations.find_by(kenshi_id: kenshi.id).team&.name.presence || "ronin"
        ].map { |s| s.to_s.gsub(",", " -") }.join(", ")
      end

      out_file.close
    end
  end
end
