# frozen_string_literal: true

# Shared seeding slice for the two things a category seeds: Participation
# (individual categories) and Team (team categories). Includers implement two
# hooks:
#   seed_group     -> the category the seed order is scoped to, and the row
#                     SeedOrderMove locks while it renumbers
#   seed_siblings  -> the relation holding everything that shares that order
#
# The seed values themselves are the panel's business: SeedOrderMove keeps them
# contiguous at 1..N, and nothing else writes them.
module Seedable
  extend ActiveSupport::Concern

  included do
    validates :seed, numericality: {only_integer: true, greater_than: 0, allow_nil: true}

    # Seeded, in seed order. The tie-break on id matters because the values can
    # briefly hold a duplicate — destroying a seeded record leaves a gap, and
    # the panel's "add" sends N + 1 — and BracketOnlySeeder breaks that tie the
    # same way, so the panel, the poolers and the draw never disagree.
    scope :seeded, -> { where.not(seed: nil).order(:seed, :id) }
  end

  class_methods do
    # The same order over records already in memory: SmartPooler, TeamPooler,
    # BracketOnlySeeder and both seeding panels all work from a list they
    # loaded for other reasons too, so none of them can use the scope without a
    # second query.
    def in_seed_order(records)
      records.select(&:seeded?).sort_by { |record| [record.seed, record.id] }
    end
  end

  def seeded?
    seed.present?
  end
end
