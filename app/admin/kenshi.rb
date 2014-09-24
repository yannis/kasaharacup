ActiveAdmin.register Kenshi do

  permit_params :id, :user, :cup_id, :last_name, :first_name, :female, :email, :dob, :email, :grade, :club_id, :user_id, purchases_attributes: [:_destroy, :product_id, :id], participations_attributes: [:id, :category_individual, :category_team, :_destroy]

  index do
    column :cup
    column :last_name
    column :first_name
    column :email
    column :categories do |kenshi|
      (kenshi.individual_categories.map{|c| link_to(c.name, [:admin, c])}+kenshi.teams.map{|t| "#{link_to(t.name, [:admin, t])} (#{link_to(t.team_category.name, [:admin, t.team_category])})"}).join(', ').html_safe
    end
    column :products do |kenshi|
      kenshi.products.map{|c| link_to(c.name, [:admin, c])}.join(', ').html_safe
    end
    column :user do |kenshi|
      "#{kenshi.user.full_name} (#{kenshi.user.email})"
    end
    actions do |kenshi|
      link_to "PDF", pdf_admin_kenshi_path(kenshi)
    end
  end

  show do |kenshi|
    attributes_table do
      row :cup
      row :first_name
      row :last_name
      row :female
      row :dob
      row :grade
      row :email
      row :club
      row :user
    end
    if kenshi.participations.present?
      panel "Participations" do
        table_for kenshi.participations.order(:category_type, :category_id) do |participation|
          column :category
          column :team
          column :ronin
          column :age do |participation|
            participation.kenshi.age_at_cup
          end
          column :pool_number
          column :pool_position
          column :admin_links do  |participation|
            [link_to("View", admin_participation_path(participation)), link_to("Edit", edit_admin_participation_path(participation)), link_to("Destroy", admin_participation_path(participation), method: :delete, confirm: "Are you sure?")].join(" ").html_safe
          end
        end
      end
    end

  end

  form do |f|
    f.object.errors
    f.semantic_errors *f.object.errors.keys
    f.inputs "Kenshi details" do
      f.input :cup
      f.input :user
      f.input :club
      f.input :female
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :dob, as: :datepicker
      f.input :grade, collection: Kenshi::GRADES
    end
    f.inputs "Participations" do
      f.has_many :participations do |j|
        j.input :category_individual, collection: IndividualCategory.all
        j.input :category_team, collection: TeamCategory.all
        j.input :_destroy, as: :boolean
      end
    end
    f.inputs "Purchases" do
      f.has_many :purchases do |j|
        j.input :product
        j.input :_destroy, as: :boolean
      end
    end

    f.actions
  end

  action_item only: :show do
    link_to "PDF", pdf_admin_kenshi_path(kenshi)
  end

  action_item only: :index do
    link_to("PDF", pdfs_admin_kenshis_path)
  end

  member_action :pdf do
    @kenshi = Kenshi.find params[:id]
    pdf = KenshiPdf.new(@kenshi)
    send_data pdf.render, filename: @kenshi.full_name.parameterize('_'),
                          type: "application/pdf",
                          disposition: "inline",
                          page_size: 'A4'

  end

  # member_action :receipt do
  #   @kenshi = Kenshi.find params[:id]
  #   pdf = KenshiReceipt.new(@kenshi)
  #   send_data pdf.render, filename: @kenshi.full_name.parameterize('_')+"_receipt",
  #                         type: "application/pdf",
  #                         disposition: "inline",
  #                         page_size: 'A4'

  # end

  collection_action :pdfs do
    @kenshis = Kenshi.order(:last_name)
    pdf = KenshisPdf.new(@kenshis)
    send_data pdf.render, filename: "kenshis",
                          type: "application/pdf",
                          disposition: "inline",
                          page_size: 'A4'
  end
end
