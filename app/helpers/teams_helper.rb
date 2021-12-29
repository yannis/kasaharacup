# frozen_string_literal: true

module TeamsHelper
  def team_admin_links(team, options = {})
    links = []
    if can?(
      :destroy, team
    )
      links << destroy_link([@current_cup, team],
        {classes: "btn-xs", title: t("teams.destroy.title"), confirm: t("teams.destroy.confirm")})
    end

    content_tag(:ul, class: "admin_links horizontal #{options[:nav] ? "nav" : nil}",
id: "#{team.class.to_s.tableize}_#{team.id}_admin_links") do
      links.each do |link|
        concat(link)
      end
    end
  end
end
