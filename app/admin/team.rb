ActiveAdmin.register Team do

  permit_params :name, :cup, :team_category

  index do
    column :name
    column :cup do |team|
      link_to(team.team_category.cup.year, team.team_category.cup) if team.team_category
    end
    column :team_category
    column :members do |team|
      team.kenshis.map{|k| link_to( k.full_name, [:admin, k])}.join(', ').html_safe
    end
    actions
  end
end
