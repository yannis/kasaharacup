# frozen_string_literal: true

module QueryCounter
  # The SQL a block sends to the database, minus what says nothing about how a
  # page scales: schema lookups, and the query-cache hits Rails serves from
  # memory within a single request.
  def count_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql]
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # Bind placeholders carry no meaning here, and a preload's `IN ($1, $2, $3)`
  # would otherwise look like a different query on every run.
  def self.shape(sql)
    sql.gsub(/\$\d+(\s*,\s*\$\d+)*/, "?").squish
  end

  # Which queries the larger run sent more often than the smaller one — the
  # N+1 itself, told apart from the queries both runs share.
  def self.growth(baseline, queries)
    before = baseline.map { |sql| shape(sql) }.tally
    after = queries.map { |sql| shape(sql) }.tally
    after.filter_map do |sql, count|
      extra = count - before.fetch(sql, 0)
      "#{extra}× #{sql.truncate(160)}" if extra.positive?
    end
  end
end

# Rendering a page over a bigger cup must not send the database more queries:
# that difference, and not any particular count, is what an N+1 is.
RSpec::Matchers.define :send_no_more_queries_than do |baseline|
  match { |queries| queries.size <= baseline.size }

  failure_message do |queries|
    ["expected no extra queries, got #{queries.size - baseline.size}:",
      *QueryCounter.growth(baseline, queries).map { |line| "  #{line}" }].join("\n")
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
