# frozen_string_literal: true

RSpec::Matchers.define_negated_matcher(:not_change, :change)
RSpec::Matchers.define_negated_matcher(:not_match, :match)
