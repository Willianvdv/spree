module Spree
  module Admin
    class CallbackedController < ResourceController

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

        run_callbacks "load_#{controller_name}_collection".to_sym do
           @collection = super
        end

        @collection
      end

      def paginate_collection
        @collection = @collection.page(params[:page]).per(per_page || 15)
      end

      def search
        @search = @collection.ransack(@search_params[:q])
        @collection = @search.result
      end
    end
  end
end