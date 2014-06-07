ActiveAdmin.register Cup do

  permit_params :year, :start_on, :end_on, :deadline, :adult_fees_chf, :adult_fees_eur, :junior_fees_chf, :junior_fees_eur

  index do
    column :year
    column :start_on
    column :end_on
    column :deadline
    column :adult_fees_chf
    column :adult_fees_eur
    column :junior_fees_chf
    column :junior_fees_eur
    actions
  end

  filter :year

  form do |f|
    f.inputs "Details" do
      f.input :start_on, as: :string, input_html: {class: "hasDatetimePicker"}
      f.input :end_on, as: :string, input_html: {class: "hasDatetimePicker"}
      f.input :deadline, as: :string, input_html: {class: "hasDatetimePicker"}
      f.input :adult_fees_chf
      f.input :adult_fees_eur
      f.input :junior_fees_chf
      f.input :junior_fees_eur
    end
    f.actions
  end

end
