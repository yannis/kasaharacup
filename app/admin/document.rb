# frozen_string_literal: true

ActiveAdmin.register Document do
  permit_params :name, :file, :locale

  menu false
  controller do
    belongs_to :individual_category, :team_category, polymorphic: true


  end

  show do
    attributes_table do
      row :name
      row :url do |document|
        link_to url_for(document.file.url), url_for(document.file.url)
      end
    end
  end

  form(title: proc { |document|
    [
      document.persisted? ? "Edit" : "New",
      "document for",
      "«#{document.category.name}»",
      "(#{document.category.cup.year})"
    ].join(" ")
  }) do |f|
    f.inputs do
      f.input :name
      f.input :file, as: :file
    end
    f.actions
  end
end
