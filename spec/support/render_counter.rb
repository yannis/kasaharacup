# frozen_string_literal: true

module RenderCounter
  # What a block rendered, named the way a controller names it: a ViewComponent
  # by its class, a partial by the path you would pass to `render`. Counting
  # renders says outright what a "built once" guard means; counting the queries
  # a render happens to emit only stands in for it, and breaks the day the
  # surface changes its scope without rendering any more often.
  def count_renders
    rendered = []
    subscriptions = [
      ActiveSupport::Notifications.subscribe("render.view_component") do |*, payload|
        rendered << payload[:name]
      end,
      ActiveSupport::Notifications.subscribe("render_partial.action_view") do |*, payload|
        rendered << RenderCounter.partial_name(payload[:identifier])
      end
    ]
    yield
    rendered
  ensure
    subscriptions.each { |subscription| ActiveSupport::Notifications.unsubscribe(subscription) }
  end

  # "…/app/views/admin/team_categories/_pool_unpooled.html.erb" becomes
  # "admin/team_categories/pool_unpooled".
  def self.partial_name(identifier)
    identifier.to_s
      .sub(%r{\A.*/app/views/}, "")
      .sub(/\.[^.\/]+\z/, "")
      .delete_suffix(".html")
      .sub(%r{(\A|/)_}, '\1')
  end
end

RSpec.configure do |config|
  config.include RenderCounter
end
