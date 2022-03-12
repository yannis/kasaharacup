# frozen_string_literal: true

ActiveAdmin.register Video do
  permit_params :name, :url

  menu false
  controller do
    belongs_to :individual_category, :team_category, polymorphic: true

    def authenticate_admin_user!
      redirect_to root_url unless current_user.try(:admin?)
    end
  end

  form(title: proc { |video|
    [
      video.persisted? ? "Edit" : "New",
      "video for",
      "«#{video.category.name}»",
      "(#{video.category.cup.year})"
    ].join(" ")
  }) do |f|
    f.inputs do
      f.input :name
      f.input :url
    end
    f.actions
  end
end
