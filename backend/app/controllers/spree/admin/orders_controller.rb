module Spree
  module Admin
    class OrdersController < ResourceController
      include CallbackedCollection

      before_filter :initialize_order_events
      before_filter :load_order, :only => [:edit, :update, :cancel, :resume, :approve, :resend, :open_adjustments, :close_adjustments]

      respond_to :html

      set_callback :load_collection, :before, :show_only_complete_orders
      set_callback :load_collection, :before, :created_in_time_span
      set_callback :load_collection, :after, :limit_accessibility

      def index
        @orders = collection
        respond_with(@orders)
      end

      def new
        @order = Order.create
        @order.created_by = try_spree_current_user
        @order.save
        redirect_to edit_admin_order_url(@order)
      end

      def edit
        unless @order.complete?
          @order.refresh_shipment_rates
        end
      end

      def update
        if @order.update_attributes(params[:order]) && @order.line_items.present?
          @order.update!
          unless @order.complete?
            # Jump to next step if order is not complete.
            redirect_to admin_order_customer_path(@order) and return
          end
        else
          @order.errors.add(:line_items, Spree.t('errors.messages.blank')) if @order.line_items.empty?
        end

        render :action => :edit
      end

      def cancel
        @order.cancel!
        flash[:success] = Spree.t(:order_canceled)
        redirect_to :back
      end

      def resume
        @order.resume!
        flash[:success] = Spree.t(:order_resumed)
        redirect_to :back
      end

      def approve
        @order.approved_by(try_spree_current_user)
        flash[:success] = Spree.t(:order_approved)
        redirect_to :back
      end

      def resend
        OrderMailer.confirm_email(@order.id, true).deliver
        flash[:success] = Spree.t(:order_email_resent)
        redirect_to :back
      end

      def open_adjustments
        adjustments = @order.adjustments.where(:state => 'closed')
        adjustments.update_all(:state => 'open')
        flash[:success] = Spree.t(:all_adjustments_opened)

        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      def close_adjustments
        adjustments = @order.adjustments.where(:state => 'open')
        adjustments.update_all(:state => 'closed')
        flash[:success] = Spree.t(:all_adjustments_closed)

        respond_with(@order) { |format| format.html { redirect_to :back } }
      end

      private
        def limit_accessibility
          @collection = @collection.accessible_by(current_ability, :index)
        end

        def show_only_complete_orders
          @search_params[:q][:completed_at_not_null] ||= '1' if Spree::Config[:show_only_complete_orders_by_default]
          @show_only_completed = @search_params[:q][:completed_at_not_null] == '1'
          @search_params[:q][:s] ||= @show_only_completed ? 'completed_at desc' : 'created_at desc'

          #if @show_only_completed
          #  params[:q][:completed_at_gt] = params[:q].delete(:created_at_gt)
          #  params[:q][:completed_at_lt] = params[:q].delete(:created_at_lt)
          #end
        end

        def created_in_time_span
          # As date params are deleted if @show_only_completed, store
          # the original date so we can restore them into the params
          # after the search

          created_at_gt = @search_params[:q][:created_at_gt]
          created_at_lt = @search_params[:q][:created_at_lt]

          # ?
          if @search_params[:q][:inventory_units_shipment_id_null] == "0"
            @search_params[:q].delete(:inventory_units_shipment_id_null)
          end

          if !@search_params[:q][:created_at_gt].blank?
            timezoned_created_at_gt = Time.zone.parse @search_params[:q][:created_at_gt]
            @search_params[:q][:created_at_gt] = timezoned_created_at_gt.beginning_of_day rescue ""
          end

          if !@search_params[:q][:created_at_lt].blank?
            timezoned_created_at_lt = Time.zone.parse @search_params[:q][:created_at_lt]
            @search_params[:q][:created_at_lt] = timezoned_created_at_lt.end_of_day rescue ""
          end
        end

        def load_order
          @order = Order.includes(:adjustments).find_by_number!(params[:id])
          authorize! action, @order
        end

        # Used for extensions which need to provide their own custom event links on the order details view.
        def initialize_order_events
          @order_events = %w{approve cancel resume}
        end

        def model_class
          Spree::Order
        end
    end
  end
end
