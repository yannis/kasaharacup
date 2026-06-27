# frozen_string_literal: true

# Kendo team-fighting role names by bout position. A full five-fighter team
# fights sempō, jihō, chūken, fukushō, taishō; a three-fighter team keeps the
# leadoff, centre and anchor roles (sempō, chūken, taishō). Sizes without a
# conventional naming fall back to a plain "Position N" so the label is always
# present.
class TeamPosition
  ROLES = {
    5 => %w[Sempo Jiho Chuken Fukusho Taisho],
    3 => %w[Sempo Chuken Taisho]
  }.freeze

  # e.g. "1. Sempo" for position 1 of a team of 5, or "Position 2" when the
  # team size has no conventional role names.
  def self.label(position, team_size)
    role = ROLES[team_size]&.[](position - 1)
    role ? "#{position}. #{role}" : "Position #{position}"
  end
end
