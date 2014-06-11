ActiveAdmin.register Event do

  permit_params :cup, :name_en, :name_fr, :start_on, :duration

  # index do
  #   column :year
  #   column :start_on
  #   column :end_on
  #   column :deadline
  #   column :adult_fees_chf
  #   column :adult_fees_eur
  #   column :junior_fees_chf
  #   column :junior_fees_eur
  #   actions
  # end

  filter :name_fr

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
