# frozen_string_literal: true

# The team sibling of IndividualCategoryPdfRecap: every pool of the category on
# one sheet, each team listed in its pool position, for the wall by the courts.
class TeamCategoryPdfRecap < Prawn::Document
  include PosterSize

  ROW_HEIGHT = 22
  # The pool label and the gap above it, on top of the pool's rows.
  POOL_MARGIN = 40

  def initialize(team_category)
    super(page_layout: :portrait)
    repeat :all, dynamic: true do
      bounding_box [bounds.left, bounds.top + 20], width: 400 do
        fill_color "000000"
        font_size 48
        text team_category.name.upcase
      end

      cup_name_and_logo(category: team_category)
    end

    move_down 40
    team_category.team_pools.each do |pool|
      # Measured rather than counted: a team category's pool size varies from
      # cup to cup, so a fixed number of pools per page overflows the larger ones.
      if cursor < pool.teams.size * ROW_HEIGHT + POOL_MARGIN
        start_new_page
        move_down 40
      end
      draw_pool(pool)
    end
  end

  private def draw_pool(pool)
    font_size 12
    move_down 12
    bounding_box [bounds.left, cursor - 10], width: 600 do
      top = cursor
      bounding_box [bounds.left, cursor], width: 70 do
        font_size 18
        text "Pool #{pool.number}", align: :right
      end
      bounding_box [bounds.left + 80, top + 20], width: 450 do
        data = pool.teams.each_with_index.map { |team, i| [i + 1, team.name] }
        table(data, cell_style: {size: 12}, width: 450) do
          column(0).width = 30
        end
      end
    end
  end
end
