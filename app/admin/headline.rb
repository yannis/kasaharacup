# frozen_string_literal: true

ActiveAdmin.register Headline, as: "Headline" do
  permit_params :title_en, :title_fr, :title_de, :content_fr, :content_en, :content_de, :shown, :cup_id

  controller do
    def scoped_collection
      super.includes(:cup)
    end
  end

  index do
    column :cup
    column :title_en
    column :title_fr
    column :title_en
    column :content_en
    column :content_fr
    column :content_de
    column :shown
    actions
  end

  show title: proc { |event| event.title } do |event|
    attributes_table do
      row :cup
      row :title_en
      row :title_fr
      row :content_en
      row :content_fr
      row :content_de
      row :shown
    end
  end

  filter :cup
  filter :title_fr
  filter :title_en
  filter :title_de
  filter :shown

  form do |f|
    f.inputs "Details" do
      f.input :cup
      f.input :title_en
      f.input :title_fr
      f.input :title_de
      f.input :content_en
      f.input :content_fr
      f.input :content_de
      f.input :shown
    end
    f.actions
  end
end
