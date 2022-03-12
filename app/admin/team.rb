# frozen_string_literal: true

ActiveAdmin.register Team, as: "Team" do
  permit_params :name, :cup, :team_category_id, :rank

  controller do
    def authenticate_admin_user!
      redirect_to root_url unless current_user.try(:admin?)
    end
  end

  index do
    column :name
    column :cup
    column :team_category
    column :rank
    column :members do |team|
      team.kenshis.map { |k| link_to(k.full_name, [:admin, k]) }.join(", ").html_safe
    end
    column :complete do |team|
      team.complete?
    end
    column :valid do |team|
      team.isvalid?
    end
    # column :total_grade do |team|
    #   team.kenshis.map{|k| k.grade.to_i}.sum
    # end
    # column :total_age do |team|
    #   team.kenshis.map{|k| k.age_at_cup.to_i}.sum
    # end
    column :fitness
    actions do |team|
      [
        link_to("PDF", pdf_admin_team_path(team))
      ].join(" ").html_safe
    end
  end

  filter :name
  filter :team_category, as: :check_boxes, collection: proc { TeamCategory.all }
  filter :rank

  show do |team|
    attributes_table do
      row :name
      row :team_category do |c|
        "#{c.team_category.name} (#{c.team_category.cup.year})"
      end
      row :rank
    end
    if team.kenshis.present?
      panel "Kenshis" do
        table do
          thead do
            tr do
              th do
                "Last name"
              end
              th do
                "First name"
              end
            end
          end
          tbody do
            team.kenshis.order(:last_name, :first_name).each do |kenshi|
              tr do
                td do
                  kenshi.last_name
                end
                td do
                  kenshi.first_name
                end
              end
            end
          end
        end
      end
    end
  end

  form do |f|
    f.semantic_errors # shows errors on :base
    f.inputs "Details" do
      f.input :team_category, collection: TeamCategory.all.map { |tc| ["#{tc.name} (#{tc.cup})", tc.id] }
      f.input :name
      f.input :rank
    end
    f.actions
  end

  member_action :pdf do
    @team = Team.find params[:id]
    pdf = TeamPdf.new(@team)
    send_data pdf.render, filename: @team.name.parameterize(separator: "_"),
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end
  action_item :pdf, only: :show do
    link_to "PDF", pdf_admin_team_path(team)
  end
end
