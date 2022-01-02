# frozen_string_literal: true

class NavigationDropdownComponentPreview < ViewComponent::Preview
  def default
    render(NavigationDropdownComponent.new(
      name: "profile",
      text: "Profile",
      links: [
        {text: "Settings", url: "#"},
        {text: "Log out", url: "#"}
      ]
    ))
  end
end
