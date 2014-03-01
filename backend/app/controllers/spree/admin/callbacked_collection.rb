module Spree
  module Admin
    module CallbackedCollection
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks

        define_callbacks :load_collection
        set_callback :load_collection, :after, :paginate_collection
        set_callback :load_collection, :after, :search
      end

      protected

      def search_params
        params[:q] ||= {}
        params
      end

      def per_page
        Spree::Config["#{controller_name}_per_page".to_sym] || 15
      end

      def collection
        return @collection if @collection.present?

        @search_params = search_params

        run_callbacks "load_collection".to_sym do
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