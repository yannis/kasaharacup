# frozen_string_literal: true

module Admin
  # Shared body of the six freeze controllers (issue #1319). Each one supplies
  # three things — the category, which flag it owns, and the streams that go
  # stale when that flag moves — and this writes the timestamp, broadcasts and
  # responds.
  #
  # The acting admin and every other open page get the identical set, built
  # once (each FreezeStreams memoises it), so the two can never drift: the
  # response renders `streams` and the
  # broadcast sends the same content on the same stream names. Every tag is a
  # replace, so the acting admin applying them twice — once from the response,
  # once from their own subscription — is idempotent.
  module Freezing
    extend ActiveSupport::Concern

    private def apply(freeze:)
      freeze ? freeze_category : unfreeze_category
      broadcast

      respond_to do |format|
        format.html { redirect_to category_path, notice: notice_for(freeze) }
        format.turbo_stream { render turbo_stream: helpers.safe_join(streams.values) }
      end
    end

    private def freeze_category
      (flag == :bracket) ? category.freeze_bracket! : category.freeze_pools!
    end

    private def unfreeze_category
      (flag == :bracket) ? category.unfreeze_bracket! : category.unfreeze_pools!
    end

    # `streams` is a stream-name => content hash, so each subscription receives
    # only what belongs to it. That matters on the team side, where the panel,
    # the pool cards and the bracket each subscribe separately: sending the
    # whole set to each would apply the others twice on a page holding more
    # than one subscription (the reasoning is spelled out at length in
    # Admin::TeamCategories::SeedsController).
    private def broadcast
      streams.each do |stream_name, content|
        Turbo::StreamsChannel.broadcast_stream_to([category, stream_name], content: content)
      end
    end

    private def notice_for(freeze)
      t("admin.freezes.#{freeze ? "frozen" : "unfrozen"}.#{flag}")
    end
  end
end
