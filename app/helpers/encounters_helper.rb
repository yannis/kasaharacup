# frozen_string_literal: true

module EncountersHelper
  # DOM id of the hidden, per-team lineup form that the in-table fighter
  # dropdowns associate with via their `form=` attribute. Scoped to the
  # encounter so the same team appearing in several round-robin encounters on
  # one page never collides.
  def lineup_form_id(encounter, team)
    "lineup_#{dom_id(encounter)}_team_#{team.id}"
  end

  # One-line state for an encounter's collapsed <summary>. Computes the
  # EncounterResult once. Checks complete? before winner because
  # EncounterResult#winner returns the leading team even mid-scoring.
  def encounter_summary_line(encounter)
    result = encounter.result
    state =
      if !result.complete?
        " — not yet scored"
      elsif result.winner
        " → #{result.winner.name}"
      else
        " — hikiwake"
      end
    "#{encounter.team_1.name} vs #{encounter.team_2.name} — " \
      "wins #{result.team_1_wins}–#{result.team_2_wins}, " \
      "ippons #{result.team_1_ippons}–#{result.team_2_ippons}#{state}"
  end
end
