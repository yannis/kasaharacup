module TeamsHelper

  def team_admin_links(team, options={})
    links = []
    links << destroy_link([@current_cup, team], {classes: "btn-xs", title: t('teams.destroy.title'), confirm: t('teams.destroy.confirm')}) if can?(:destroy, team)

    return content_tag(:ul, class: "admin_links horizontal #{options[:nav] ? 'nav' : nil}", id: "#{team.class.to_s.tableize}_#{team.id}_admin_links") do
      for link in links
        concat(link)
      end
    end
  end
end
