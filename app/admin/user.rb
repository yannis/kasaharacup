# frozen_string_literal: true

ActiveAdmin.register User, as: "User" do
  permit_params :first_name, :last_name, :email, :club, :dob, :club_id, :password, :password_confirmation

  controller do
    def authenticate_admin_user!
      redirect_to root_url unless current_user.try(:admin?)
    end
  end

  index do
    column :first_name
    column :last_name
    column :email
    column :club
    column :dob
    column :current_sign_in_at
    column :last_sign_in_at
    column :sign_in_count
    column :admin
    column :provider
    actions
  end

  filter :first_name
  filter :last_name
  filter :email
  filter :admin

  show do |user|
    attributes_table do
      row :last_name
      row :first_name
      row :email
      row :club
      row :dob
      row :admin
    end

    if user.kenshis.present?
      panel "Kenshis" do
        table_for user.kenshis.order(:last_name, :first_name) do |kenshi|
          column :full_name do |k|
            link_to k.full_name, [:admin, k]
          end
          column :email
          column :club
          column :user do |kenshi|
            "#{kenshi.user.full_name} (#{kenshi.user.email})"
          end
        end
      end
    end
  end

  form do |f|
    f.inputs "User details" do
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :club
      f.input :dob, as: :datepicker
      # f.input :password
      # f.input :password_confirmation
    end
    f.actions
  end

  action_item :receipt, only: :show do
    link_to "Receipt", receipt_admin_user_path(user)
  end

  member_action :receipt do
    @user = User.find params[:id]
    pdf = UserReceipt.new(@user)
    send_data pdf.render, filename: @user.full_name.parameterize(separator: "_") + "_receipt",
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end
end
