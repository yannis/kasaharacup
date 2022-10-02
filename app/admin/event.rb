# frozen_string_literal: true

ActiveAdmin.register Event, as: "Event" do
  permit_params :cup_id, :name_en, :name_fr, :start_on, :duration

  controller do
    def scoped_collection
      super.includes(:cup)
    end
  end

  index do
    column :name_en do |c|
      link_to "#{c.name_en} (#{c.year})", [:admin, c]
    end
    column :name_fr do |c|
      link_to "#{c.name_fr} (#{c.year})", [:admin, c]
    end
    column :start_on
    column :duration
    actions
  end

  filter :name_en
  filter :name_fr
  filter :cup

  form do |f|
    f.inputs "Details" do
      f.input :cup
      f.input :name_en
      f.input :name_fr
      f.input :start_on, as: :string, input_html: {class: "hasDatetimePicker"}
      f.input :duration
    end
    f.actions
  end
end
