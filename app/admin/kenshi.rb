# frozen_string_literal: true

ActiveAdmin.register Kenshi, as: "Kenshi" do
  permit_params :id, :user, :cup_id, :last_name, :first_name, :female, :email,
    :dob, :email, :grade, :club_id, :user_id, :remarks, :shinpan,
    purchases_attributes: [:_destroy, :product_id, :id],
    participations_attributes: [:id, :category_individual, :category_team, :_destroy]

  controller do
    def scoped_collection
      super.includes(:cup, :club, :user, participations: :category, purchases: :product)
    end
  end

  csv do
    column :cup
    column :last_name
    column :first_name
    column :email
    column :grade
    column :shinpan
    column :individual_categories do |kenshi|
      kenshi.individual_categories.map(&:name).join(", ")
    end
    column :team_categories do |kenshi|
      kenshi.teams.map(&:name).join(", ")
    end
    column :products do |kenshi|
      kenshi.products.map(&:name).join(", ")
    end
    column :user do |kenshi|
      "#{kenshi.user.full_name} (#{kenshi.user.email})"
    end
    column :remarks
  end

  filter :cup
  filter :first_name
  filter :last_name
  filter :email
  filter :grade
  filter :shinpan
  filter :products, as: :check_boxes, collection: proc {
                                                    Product.all.map { |p|
                                                      ["#{p.name} (#{p.year})", p.id]
                                                    }
                                                  }
  filter :remarks

  index do
    column :cup
    column :last_name do |kenshi|
      link_to kenshi.last_name, [:admin, kenshi]
    end
    column :first_name
    column :email
    column :grade
    column :shinpan
    column :individual_categories do |kenshi|
      kenshi.individual_categories.map { |c| link_to(c.name, admin_individual_category_path(c)) }.join(", ").html_safe
    end
    column :team_categories do |kenshi|
      kenshi.teams.map { |t| link_to t.name, admin_team_path(t) }.join(", ").html_safe
    end
    column :products do |kenshi|
      kenshi.products.map { |c| link_to(c.name, admin_product_path(c)) }.join(", ").html_safe
    end
    column :personal_info do |kenshi|
      kenshi.personal_info.present?
    end
    column :user do |kenshi|
      "#{kenshi.user.full_name} (#{kenshi.user.email})"
    end
    column :remarks
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
      row :shinpan
      row :email
      row :club
      row :user
      row :remarks
    end
    if kenshi.personal_info.present?
      panel "Personal info" do
        attributes_table_for kenshi.personal_info do
          row :email
          row :residential_address
          row :residential_zip_code
          row :residential_city
          row :residential_country
          row :residential_phone_number
          row :origin_country
          row :document_type
          row :document_number
        end
      end
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
          column :admin_links do |participation|
            [
              link_to("View", admin_participation_path(participation)),
              link_to("Edit", edit_admin_participation_path(participation)),
              link_to("Destroy", admin_participation_path(participation), method: :delete, confirm: "Are you sure?")
            ].join(" ").html_safe
          end
        end
      end
    end
    if kenshi.purchases.present?
      panel "Purchase" do
        table_for kenshi.purchases do |purchase|
          column :product
          column :admin_links do |purchase|
            [
              link_to("View", admin_purchase_path(purchase)),
              link_to("Edit", edit_admin_purchase_path(purchase)),
              link_to("Destroy", admin_purchase_path(purchase), method: :delete, confirm: "Are you sure?")
            ].join(" ").html_safe
          end
        end
      end
    end
  end

  form do |f|
    f.object.errors
    f.semantic_errors
    f.inputs "Kenshi details" do
      f.input :cup
      f.input :user, collection: User
        .order(:last_name, :first_name)
        .map { |u| ["#{u.last_name} #{u.first_name}", u.id] }
      f.input :club, collection: Club.order(:name)
      f.input :female, as: :radio, collection: {Ms: true, "M.": false}
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :dob, as: :datepicker
      f.input :grade, collection: Kenshi::GRADES
      f.input :shinpan, as: :radio, collection: {Yes: true, No: false}
      f.input :remarks
    end
    if f.object.persisted?
      f.inputs "Participations" do
        f.has_many :participations do |j|
          j.input :category_individual, collection: f.object.cup.individual_categories.order(:name)
          j.input :category_team, collection: f.object.cup.team_categories.order(:name)
          j.input :_destroy, as: :boolean
        end
      end
      f.inputs "Purchases" do
        f.has_many :purchases do |j|
          j.input :product, collection: f.object.cup.products.order(:name_fr)
          j.input :_destroy, as: :boolean
        end
      end
    end

    f.actions
  end

  action_item :pdf_show, only: :show do
    link_to "PDF", pdf_admin_kenshi_path(kenshi)
  end

  action_item :pdf_index, only: :index do
    link_to("PDF", pdfs_admin_kenshis_path)
    link_to("Dormitory CSV", dormitory_csv_admin_kenshis_path)
  end

  member_action :pdf do
    @kenshi = Kenshi.find params[:id]
    pdf = KenshiPdf.new(@kenshi)
    send_data(pdf.render, filename: @kenshi.full_name.parameterize(separator: "_"))
  end

  # member_action :receipt do
  #   @kenshi = Kenshi.find params[:id]
  #   pdf = KenshiReceipt.new(@kenshi)
  #   send_data pdf.render, filename: @kenshi.full_name.parameterize(separator: '_')+"_receipt",
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
      page_size: "A4"
  end

  collection_action :dormitory_csv do
    cup = Cup.last
    products = cup.products.where(require_personal_infos: true)
    purchases = Purchase.where(product: products)
    kenshis = Kenshi.order(:last_name, :first_name).joins(:purchases).merge(purchases).distinct
    csv = CSV.generate do |csv|
      csv_header = [
        "Last name",
        "First name",
        "Sex",
        "Birth date",
        "Email",
        "Residential address",
        "Residential zip code",
        "Residential city",
        "Residential country",
        "Residential phone number",
        "Origin country",
        "Document type",
        "Document number"
      ]
      products.each do |product|
        csv_header << product.name
      end
      csv << csv_header
      kenshis.each do |kenshi|
        csv_kenshi = [
          kenshi.last_name,
          kenshi.first_name,
          kenshi.female ? "F" : "M",
          kenshi.dob,
          kenshi.email.presence || kenshi.user.email,
          kenshi.personal_info.residential_address,
          kenshi.personal_info.residential_zip_code,
          kenshi.personal_info.residential_city,
          kenshi.personal_info.residential_country,
          kenshi.personal_info.residential_phone_number,
          kenshi.personal_info.origin_country,
          kenshi.personal_info.document_type,
          kenshi.personal_info.document_number
        ]
        products.each do |product|
          csv_kenshi << (kenshi.purchases.pluck(:product_id).include?(product.id) ? "Yes" : "")
        end
        csv << csv_kenshi
      end
    end
    send_data csv, filename: "kenshis_dormitory_#{cup.year}.csv",
      type: "text/csv",
      disposition: "inline"
  end
end
