# frozen_string_literal: true

module EncountersHelper
  # DOM id of the hidden, per-team lineup form that the in-table fighter
  # dropdowns associate with via their `form=` attribute. Scoped to the
  # encounter so the same team appearing in several pool encounters on
  # one page never collides.
  def lineup_form_id(encounter, team)
    "lineup_#{dom_id(encounter)}_team_#{team.id}"
  end

  # DOM id of the hidden daihyōsen form the rep dropdowns associate with.
  def daihyosen_form_id(encounter)
    "daihyosen_#{dom_id(encounter)}"
  end

  # Score + outcome for an encounter's <summary>, without the team names — those
  # head each column in the summary itself. Computes the EncounterResult once,
  # and checks complete? before winner because EncounterResult#winner returns
  # the leading team even mid-scoring.
  def encounter_summary_status(encounter)
    result = encounter.result
    state =
      if !result.complete?
        " — not yet scored"
      elsif result.winner
        " → #{result.winner.name}"
      else
        " — hikiwake"
      end
    "wins #{result.team_1_wins}–#{result.team_2_wins}, " \
      "ippons #{result.team_1_ippons}–#{result.team_2_ippons}#{state}"
  end
end
