# frozen_string_literal: true

require_relative "add_results"
namespace :temporary do
  namespace :cups do
    desc "Add results, documents and videos for 2014"
    task add_2014: :environment do
      include AddResults

      cup = Cup.find_by!(year: 2014)
      add_team_results(
        cup: cup,
        team_names: ["BUDO XI", "Swiss Men 1", "Alessandria", "Saint Etienne"],
        videos: [{name: "Final video (BUDO IX vs Swiss Team)", url: "https://www.youtube.com/watch?v=bosfNhQq5Dg"}],
        documents: [
          {file_path: "2014/KASA_TEAM_2_2014.pdf", name: "Tree"}
        ]
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
        videos: [{name: "Kasahara Kendo Cup 2014, Open final (Mandia vs Kimura)", url: "https://www.youtube.com/watch?v=-qOLAfiTeKs"}],
        documents: [
          {file_path: "2014/open_pools.pdf", name: "Pools"},
          {file_path: "2014/KASA_OPEN_A1_2014.pdf", name: "Tree A1"},
          {file_path: "2014/KASA_OPEN_A2_2014.pdf", name: "Tree A2"},
          {file_path: "2014/KASA_OPEN_B1_2014.pdf", name: "Tree B1"},
          {file_path: "2014/KASA_OPEN_B2_2014.pdf", name: "Tree B2"}
        ]
      )
      add_individual_results(
        cup: cup,
        category_name: "ladies",
        kenshi_names: [
          ["Sabrina", "Kumpf"],
          ["Pauline", "Stolarz"],
          ["Safiyah", "Fadai"],
          ["Misato", "Chiba"],
          ["Kathrin", "Köppe"]
        ],
        videos: [{name: "Kasahara Kendo Cup 2014, Ladies final (Kumpf vs Stolarz)", url: "https://www.youtube.com/watch?v=U8xJlHvaBq8"}],
        documents: [
          {file_path: "2014/ladies_pools.pdf", name: "Pools"},
          {file_path: "2014/KASA_LADIES_2014.pdf", name: "Tree"}
        ]
      )
      add_individual_results(
        cup: cup,
        category_name: "junior1",
        kenshi_names: [
          ["Ugo", "Goliard"],
          ["Theo", "Renz"],
          ["Thaís", "Kimura"],
          ["Takumi", "Henry-Viel"],
          ["Leonie", "Lafont"]
        ],
        documents: [
          {file_path: "2014/junior1_pools.pdf", name: "Pools"},
          {file_path: "2014/KASA_JUNIORS_2014.pdf", name: "Tree"}
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
        videos: [{name: "Kasahara Kendo Cup 2014, Junior2 final (Sayad vs Moutarde)", url: "https://www.youtube.com/watch?v=nUm1dAZJO68"}],
        documents: [
          {file_path: "2014/junior2_pools.pdf", name: "Pools"},
          {file_path: "2014/KASA_JUNIORS_2_2014.pdf", name: "Tree"}
        ]
      )
    end
  end
end
