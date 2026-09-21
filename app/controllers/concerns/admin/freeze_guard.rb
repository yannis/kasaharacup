# frozen_string_literal: true

module Admin
  # Refuses the admin paths that would rebuild a frozen pool formation or a
  # frozen bracket (issue #1319, R4).
  #
  # HALTING IS THE CALLER'S JOB. Every guard returns true when it refused and
  # false when it did not, because a render from inside an action body does not
  # halt the action the way a before_action render does. In-action call sites
  # read:
  #
  #   return if guard_frozen_pools!(category)
  #
  # Forget the `return` and the action carries on to render a second time,
  # which raises AbstractController::DoubleRenderError rather than silently
  # letting the change through — loud, but still a bug. Where the category can
  # be found without the action body, a plain before_action is used instead and
  # the render halts on its own.
  #
  # INCLUDED TWICE. Admin::BaseController covers the hand-written controllers.
  # The ActiveAdmin member actions — reset_smart_pools, generate_pools,
  # generate_bracket — run in an ActiveAdmin::ResourceController, which is a
  # sibling of Admin::BaseController and not a subclass, so app/admin's two
  # registration files include this in their own `controller do` blocks.
  module FreezeGuard
    extend ActiveSupport::Concern

    # A pool-formation change is refused while the pools are frozen, and also
    # while the BRACKET is frozen: PoolMembershipMove#clear_bracket! and its
    # team twin destroy the tree as a side effect of any move, so an unfrozen
    # pool would otherwise be a back door into a frozen bracket (R5).
    private def guard_frozen_pools!(category)
      return refuse(t("admin.freezes.refused.pools")) if category.pools_frozen?
      return refuse(t("admin.freezes.refused.bracket_blocks_pools")) if category.bracket_frozen?

      false
    end

    private def guard_frozen_bracket!(category)
      return refuse(t("admin.freezes.refused.bracket")) if category.bracket_frozen?

      false
    end

    # Either flag blocks a seed change, for two different reasons: on a pooled
    # category the seeds drive the draw, and on a bracket-only team category
    # they drive the byes and the protected bracket positions. So this reports
    # whichever flag is actually set rather than always blaming the pools.
    private def guard_frozen_seeds!(category)
      return refuse(t("admin.freezes.refused.pools")) if category.pools_frozen?
      return refuse(t("admin.freezes.refused.bracket")) if category.bracket_frozen?

      false
    end

    # 403, NOT 422. pool_membership_controller.js treats every 422 as
    # "destructive — confirm and retry with force=true", and a freeze must
    # never be force-able, so it needs a status of its own (R12). The three
    # drag clients send Accept: text/vnd.turbo-stream.html only, so they land
    # in the first branch and read the same {message:} shape their 422 handler
    # already parses.
    private def refuse(message)
      respond_to do |format|
        format.turbo_stream { render json: {message: message}, status: :forbidden }
        format.json { render json: {message: message}, status: :forbidden }
        format.html { redirect_back_or_to admin_root_path, alert: message }
      end
      true
    end
  end
end
