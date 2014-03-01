module Spree
  module Admin
    class CallbackedController < ResourceController
      include ActiveSupport::Callbacks

      define_callbacks :load_collection
      set_callback :load_collection, :after, :paginate_collection, prepend: true
      set_callback :load_collection, :after, :search, prepend: true

      protected

      def search_params
        params[:q] ||= {}
        params
      end

      def per_page
        params[:per_page]
      end

      def collection
        return @collection if @collection.present?

        @search_params = search_params

        run_callbacks :load_collection do
           @collection = super
        end

        @collection
      end

      def paginate_collection
        @collection = @collection.page(params[:page]).per(per_page || 15)
      end

      def search
        @search = @collection.ransack(@search_params[:q])
        @collection = @search.result(distinct: true)
      end
    end
  end
end