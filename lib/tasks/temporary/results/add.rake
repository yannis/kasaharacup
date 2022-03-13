# frozen_string_literal: true

namespace :temporary do
  namespace :cups do
    desc "Add past results, documents and videos"
    task add: :environment do
      ActiveRecord::Base.transaction do
        add_2014
        add_2015
        add_2016
        add_2017
        add_2018
        add_2019
      end
    end

    private def add_2014
      cup = Cup.find_by!(year: 2014)
      add_team_results(
        cup: cup,
        team_names: ["BUDO XI", "Swiss Men 1", "Alessandria", "Saint Etienne"],
        videos: [{name: "Final video (BUDO IX vs Swiss Team)", url: "https://www.youtube.com/watch?v=bosfNhQq5Dg"}]
      )
      add_individual_results(
        cup: cup,
        category_name: "open",
        kenshi_names: [
          ["Fabrizio", "Mandia"],
          ["Oscar", "Kimura"],
          ["Arnaud", "Pons"],
          ["Yannick", "Rothacher"],
          ["Tom", "Widdows"]
        ],
        videos: [{name: "Kasahara Kendo Cup 2014, Open final (Mandia vs Kimura)", url: "https://www.youtube.com/watch?v=-qOLAfiTeKs"}]
      )
      add_individual_results(
        cup: cup,
        category_name: "ladies",
        kenshi_names: [
          ["Sabrina", "Kumpf"],
          ["Pauline", "Stolarz"],
          ["Safia", "Fadai"],
          ["Misato", "Chiba"],
          ["Catherine", "Köppe"]
        ],
        videos: [{name: "Kasahara Kendo Cup 2014, Ladies final (Kumpf vs Stolarz)", url: "https://www.youtube.com/watch?v=U8xJlHvaBq8"}]
      )
      add_individual_results(
        cup: cup,
        category_name: "junior1",
        kenshi_names: [
          ["Ugo", "Goliard"],
          ["Theo", "Renz"],
          ["Thais", "Kimura"],
          ["Takumi", "Henri-Viel"],
          ["Léonie", "Lafont"]
        ]
      )
      add_individual_results(
        cup: cup,
        category_name: "junior2",
        kenshi_names: [
          ["Louis", "Moutarde"],
          ["Gilliam", "Sayad"],
          ["Masahiro", "Ueda"],
          ["Guillaume", "Buob"],
          ["Erik", "Koller"]
        ],
        videos: [{name: "Kasahara Kendo Cup 2014, Junior2 final (Sayad vs Moutarde)", url: "https://www.youtube.com/watch?v=nUm1dAZJO68"}]
      )
    end

    private def add_team_results(cup:, team_names:, videos: [])
      category = cup.team_categories.first
      team_names.each_with_index do |name, index|
        rank = index == 3 ? 3 : index + 1
        category.teams.find_by!(name: name).update!(rank: rank)
      end
      create_videos(category: category, videos: videos)
    end

    private def add_individual_results(cup:, category_name:, kenshi_names:, videos: [])
      category = cup.individual_categories.find_by!(name: "open")
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
          .kenshis
          .find_by!(first_name: first_name, last_name: last_name)
          .update!(rank: rank, fighting_spirit: fighting_spirit)
      end
      create_videos(category: category, videos: videos)
    end

    private def create_videos(category:, videos: [])
      videos.each do |video|
        category.videos.create!(name: video.fetch(:name), url: video.fetch(:url))
      end
    end
  end
end
