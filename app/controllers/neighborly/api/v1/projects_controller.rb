module Neighborly::Api
  module V1
    class ProjectsController < Neighborly::Api::BaseController
      include PaginatedController

      has_scope :by_category_id, :order_by
      has_scope :pg_search, as: :query
      has_scope :between_created_at,
        :between_expires_at,
        :between_online_date,
        using: %i(starts_at ends_at),
        type:  :hash

      def index
        respond_with_pagination apply_scopes(scoped_by_state).all
      end

      private

      def scoped_by_state
        state_scopes = params.slice(*Project.state_names).keys
        if state_scopes.any?
          Project.with_state(state_scopes)
        else
          Project
        end
      end
    end
  end
end
