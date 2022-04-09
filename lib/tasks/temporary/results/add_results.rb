# frozen_string_literal: true

module AddResults
  private def clean_kenshis
    Kenshi.find_each do |kenshi|
      kenshi.update_columns(
        first_name: kenshi.first_name.strip,
        last_name: kenshi.last_name.strip
      )
    end

    Kenshi.find_by(last_name: "HENRY-VIEL")&.update_columns(last_name: "Henry-Viel")
    Kenshi.find_by(last_name: "sayad")&.update_columns(last_name: "Sayad")
  rescue => e
    debugger
  end

  private def clean_teams
    Team.find_each do |team|
      team.update_columns(
        name: team.name.strip
      )
    end
  rescue => e
    debugger
  end

  private def add_team_results(cup:, team_names:, videos: [], documents: [])
    category = cup.team_categories.first
    team_names.each_with_index do |name, index|
      rank = index == 3 ? 3 : index + 1
      category.teams.find_by!(name: name).update!(rank: rank)
    end
    create_videos(category: category, videos: videos)
    create_documents(category: category, documents: documents)
  rescue => e
    debugger
  end

  private def add_individual_results(cup:, category_name:, kenshi_names:, videos: [], documents: [])
    category = cup.individual_categories.find_by!(name: category_name)
    kenshi_names.each_with_index do |name, index|
      first_name, last_name = name
      if index > 3
        rank = nil
        fighting_spirit = true
      else
        rank = index == 3 ? 3 : index + 1
        fighting_spirit = false
      end
      category
        .participations
        .find_by!(kenshi: Kenshi.where(first_name: first_name, last_name: last_name))
        .update!(rank: rank, fighting_spirit: fighting_spirit)
    rescue
      debugger
    end
    create_videos(category: category, videos: videos)
    create_documents(category: category, documents: documents)
  end

  private def create_videos(category:, videos: [])
    videos.each do |video|
      category.videos.create!(name: video.fetch(:name), url: video.fetch(:url))
    end
  rescue
    debugger
  end

  private def create_documents(category:, documents: [])
    documents.each do |document|
      doc = Document.create!(name: document[:name], category: category)
      doc.file.attach(
        io: File.open(Rails.root.join("lib/temporary/documents", document[:file_path])),
        filename: "#{document[:name]}.pdf"
      )
    end
  rescue => e
    debugger
  end
end
