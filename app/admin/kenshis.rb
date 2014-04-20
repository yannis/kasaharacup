ActiveAdmin.register Kenshi do

  index do
    column :last_name #do |kenshi|
    #   link_to kenshi.norm_last_name, admin_kenshi_path(kenshi)
    # end
    column :first_name #do |kenshi|
    #   link_to kenshi.norm_first_name, admin_kenshi_path(kenshi)
    # end
    column :email
    # column :team do |kenshi|
    #   link_to( kenshi.team, kenshi.team) if kenshi.team
    # end
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
    default_actions
  end

  # action_item only: :show do
  #   link_to "PDF", pdf_admin_kenshi_path(kenshi)
  # end

  # action_item only: :show do
  #   link_to "Receipt", receipt_admin_kenshi_path(kenshi)
  # end

  # action_item only: :index do
  #   link_to("PDF", pdfs_admin_kenshis_path)
  # end

  # member_action :pdf do
  #   @kenshi = Kenshi.find params[:id]
  #   pdf = KenshiPdf.new(@kenshi)
  #   send_data pdf.render, filename: @kenshi.full_name.parameterize('_'),
  #                         type: "application/pdf",
  #                         disposition: "inline",
  #                         page_size: 'A4'

  # end

  # member_action :receipt do
  #   @kenshi = Kenshi.find params[:id]
  #   pdf = KenshiReceipt.new(@kenshi)
  #   send_data pdf.render, filename: @kenshi.full_name.parameterize('_')+"_receipt",
  #                         type: "application/pdf",
  #                         disposition: "inline",
  #                         page_size: 'A4'

  # end

  # collection_action :pdfs do
  #   @kenshis = Kenshi.order(:last_name)
  #   pdf = KenshisPdf.new(@kenshis)
  #   send_data pdf.render, filename: "kenshis",
  #                         type: "application/pdf",
  #                         disposition: "inline",
  #                         page_size: 'A4'
  # end
end
