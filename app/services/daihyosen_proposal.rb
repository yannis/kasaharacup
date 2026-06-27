# frozen_string_literal: true

# Auto-creates the daihyōsen bout when a bracket encounter is complete and level
# (equal wins AND equal ippons), pre-filled with each team's taishō (last filled
# position). Advisory: the bout is persisted but winner-less; the admin edits the
# reps and scores it. No-op unless a tie genuinely needs deciding, and idempotent
# under the concurrent scoring/draw callbacks that drive recompute_winner!.
class DaihyosenProposal
  def initialize(encounter)
    @encounter = encounter
  end

  def ensure!
    return if @encounter.pool_number.present?

    result = @encounter.result
    return unless result.complete? && result.winner.nil?
    return if @encounter.team_fights.reload.any?(&:daihyosen?)

    rep_1 = taisho(1)
    rep_2 = taisho(2)
    return unless rep_1 && rep_2 # degenerate all-void/forfeit tie: nothing to propose

    @encounter.team_fights.create!(
      daihyosen: true,
      position: @encounter.team_size + 1,
      kenshi_1_id: rep_1.id,
      kenshi_2_id: rep_2.id
    )
    @encounter.team_fights.reset
  rescue ActiveRecord::RecordNotUnique
    # A concurrent recompute already created it; treat as success.
    @encounter.team_fights.reset
  end

  # The fighter at the last filled regular position on this side, or nil.
  private def taisho(slot)
    @encounter.team_fights
      .reject(&:daihyosen?)
      .reverse_each
      .filter_map { |fight| fight.public_send(:"kenshi_#{slot}") }
      .first
  end
end
