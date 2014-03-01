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

      def collection
        return @collection if @collection.present?

        run_callbacks :load_collection do
           @collection = super
        end

        @collection
      end

      def paginate_collection
        # TODO: Dont use hard code per page
        @collection = @collection.page(params[:page]).per(15)
      end

      def search
        @search = @collection.ransack(search_params[:q])
        @collection = @search.result
      end
    end
  end
end