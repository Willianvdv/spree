module Spree
  module Admin
    class ProductsController < CallbackedController
      include ActiveSupport::Callbacks

      helper 'spree/products'

      before_filter :load_data, :except => :index

      create.before :create_before
      update.before :update_before
      helper_method :clone_object_url

      define_callbacks :load_products_collection
      set_callback :load_products_collection, :before, :update_search_params
      set_callback :load_products_collection, :before, :remove_deleted_at_from_search_params
      set_callback :load_products_collection, :after, :include_deleted_products_if_needed
      set_callback :load_products_collection, :after, :decorate_collection
      set_callback :load_products_collection, :after, :paginate_collection
      set_callback :load_products_collection, :after, :search

      def show
        session[:return_to] ||= request.referer
        redirect_to( :action => :edit )
      end

      def index
        session[:return_to] = request.url
        respond_with(@collection)
      end

      def update
        if params[:product][:taxon_ids].present?
          params[:product][:taxon_ids] = params[:product][:taxon_ids].split(',')
        end
        if params[:product][:option_type_ids].present?
          params[:product][:option_type_ids] = params[:product][:option_type_ids].split(',')
        end
        invoke_callbacks(:update, :before)
        if @object.update_attributes(permitted_resource_params)
          invoke_callbacks(:update, :after)
          flash[:success] = flash_message_for(@object, :successfully_updated)
          respond_with(@object) do |format|
            format.html { redirect_to location_after_save }
            format.js   { render :layout => false }
          end
        else
          # Stops people submitting blank slugs, causing errors when they try to update the product again
          @product.slug = @product.slug_was if @product.slug.blank?
          invoke_callbacks(:update, :fails)
          respond_with(@object)
        end
      end

      def destroy
        @product = Product.friendly.find(params[:id])
        @product.destroy

        flash[:success] = Spree.t('notice_messages.product_deleted')

        respond_with(@product) do |format|
          format.html { redirect_to collection_url }
          format.js  { render_js_for_destroy }
        end
      end

      def clone
        @new = @product.duplicate

        if @new.save
          flash[:success] = Spree.t('notice_messages.product_cloned')
        else
          flash[:success] = Spree.t('notice_messages.product_not_cloned')
        end

        redirect_to edit_admin_product_url(@new)
      end

      def stock
        @variants = @product.variants
        @variants = [@product.master] if @variants.empty?
        @stock_locations = StockLocation.accessible_by(current_ability, :read)
        if @stock_locations.empty?
          flash[:error] = Spree.t(:stock_management_requires_a_stock_location)
          redirect_to admin_stock_locations_path
        end
      end

      private

      def update_search_params
        @search_params[:q][:deleted_at_null] ||= "1"
        @search_params[:q][:s] ||= "name asc"
      end

      def remove_deleted_at_from_search_params
        # Hackish. Without this ranshack will filter on `deleted_at_null`. But we want to use
        # the `with_deleted` method. So by deleting `deleted_at_null` the order of load_collection
        # callbacks doen't effect the collection query
        @index_includes_deleted_products = @search_params[:q].delete(:deleted_at_null).blank?
      end

      def decorate_collection
        @collection = @collection.distinct_by_product_ids(@search_params[:q][:s])
                                 .includes(product_includes)
      end

      def include_deleted_products_if_needed
        @collection = @collection.with_deleted if @index_includes_deleted_products
      end

      protected

        def find_resource
          Product.with_deleted.friendly.find(params[:id])
        end

        def location_after_save
          spree.edit_admin_product_url(@product)
        end

        def load_data
          @taxons = Taxon.order(:name)
          @option_types = OptionType.order(:name)
          @tax_categories = TaxCategory.order(:name)
          @shipping_categories = ShippingCategory.order(:name)
        end

        def create_before
          return if params[:product][:prototype_id].blank?
          @prototype = Spree::Prototype.find(params[:product][:prototype_id])
        end

        def update_before
          # note: we only reset the product properties if we're receiving a post from the form on that tab
          return unless params[:clear_product_properties]
          params[:product] ||= {}
        end

        def product_includes
          [{ :variants => [:images, { :option_values => :option_type }],
             :master => [:images, :default_price]}]
        end

        def clone_object_url resource
          clone_admin_product_url resource
        end

        def permit_attributes
          params.require(:product).permit!
        end
    end
  end
end
