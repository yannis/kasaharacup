ActiveAdmin.register Kenshi do

  permit_params :user, :cup, :last_name, :first_name, :female, :email, :dob, :email, :grade, :club_id

  index do
    column :last_name #do |kenshi|
    #   link_to kenshi.norm_last_name, admin_kenshi_path(kenshi)
    # end
    column :first_name #do |kenshi|
    #   link_to kenshi.norm_first_name, admin_kenshi_path(kenshi)
    # end
    column :email
    column :categories do |kenshi|
      (kenshi.individual_categories.map{|c| link_to(c.name, [:admin, c])}+kenshi.teams.map{|t| "#{link_to(t.name, [:admin, t])} (#{link_to(t.team_category.name, [:admin, t.team_category])})"}).join(', ').html_safe
    end
    # column :norm_club
    # column :grade
    # column :ronin
    # column :open
    # column :ladies
    # column :juniors
    # column :female
    # column :absent
    # # column :created_at
    column :user do |kenshi|
      "#{kenshi.user.full_name} (#{kenshi.user.email})"
    end
    # column :updated_at
    # column 'PDF' do |kenshi|
    #   link_to "PDF", pdf_admin_kenshi_path(kenshi)
    # end
    actions do |kenshi|
      link_to "PDF", pdf_admin_kenshi_path(kenshi)
    end
  end

  action_item only: :show do
    link_to "PDF", pdf_admin_kenshi_path(kenshi)
  end

  # action_item only: :show do
  #   link_to "Receipt", receipt_admin_kenshi_path(kenshi)
  # end

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
