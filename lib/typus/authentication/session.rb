module Typus
  module Authentication
    module Session

      protected

      include Base

      def authenticate
        session[:typus_user_id] ? admin_user : redirect_to(new_admin_session_path)
      end

      def deauthenticate
        session[:typus_user_id] = nil
        ::I18n.locale = ::I18n.default_locale
        redirect_to new_admin_session_path
      end

      #--
      # Return the current user. If role does not longer exist on the system
      # admin_user will be signed out from the system.
      #++
      def admin_user
        @admin_user ||= Typus.user_class.find_by_id(session[:typus_user_id])

        if !@admin_user || !Typus::Configuration.roles.has_key?(@admin_user.role) || !@admin_user.status
          deauthenticate
        end

        @admin_user
      end

      #--
      # This method checks if the user can perform the requested action.
      # It works on models, so its available on the `resources_controller`.
      #++
      def check_if_user_can_perform_action_on_resources
        if @item && @item.is_a?(Typus.user_class)
          check_if_user_can_perform_action_on_user
        else
          not_allowed if admin_user.cannot?(params[:action], @resource.model_name)
        end
      end

      #--
      # Action is available on: edit, update, toggle and destroy
      #++
      def check_if_user_can_perform_action_on_user
        is_current_user = (admin_user == @item)

        case params[:action]
        when 'edit', 'destroy'
          # Edit/Destroy other items is not allowed unless current user is root
          # and is not the current user.
          not_allowed if admin_user.is_not_root? && !is_current_user
        when 'toggle'
          not_allowed if admin_user.is_not_root? || (admin_user.is_root? && is_current_user)
        when 'update'
          # Admin can update himself except setting the status to false!. Other
          # users can update their profile as the attributes (role & status)
          # are protected.
          if admin_user.is_root? && is_current_user
            not_allowed
          end

          if admin_user.is_not_root? && !is_current_user
            not_allowed
          end
        end
      end

      #--
      # This method checks if the user can perform the requested action.
      # It works on a resource: git, memcached, syslog ...
      #++
      def check_if_user_can_perform_action_on_resource
        resource = params[:controller].remove_prefix.camelize
        not_allowed if admin_user.cannot?(params[:action], resource, { :special => true })
      end

      def not_allowed
        render :text => "Not allowed!", :status => :unprocessable_entity
      end

      #--
      # If item is owned by another user, we only can perform a show action on
      # the item. Updated item is also blocked.
      #++
      def check_resource_ownership
        if admin_user.is_not_root?

          condition_typus_users = @item.respond_to?(Typus.relationship) && !@item.send(Typus.relationship).include?(admin_user)
          condition_typus_user_id = @item.respond_to?(Typus.user_foreign_key) && !admin_user.owns?(@item)

          not_allowed if (condition_typus_users || condition_typus_user_id)
        end
      end

      #--
      # Show only related items it @resource has a foreign_key (Typus.user_foreign_key)
      # related to the logged user.
      #++
      def check_resources_ownership
        if admin_user.is_not_root? && @resource.typus_user_id?
          @resource = @resource.where(Typus.user_foreign_key => admin_user)
        end
      end

      ##
      # OPTIMIZE: This method should accept args.
      #
      def set_attributes_on_create
        @item.send("#{Typus.user_foreign_key}=", admin_user.id) if @resource.typus_user_id?
      end

      ##
      # OPTIMIZE: This method should accept args and not perform an update
      #           because we are updating the attributes twice!
      #
      def set_attributes_on_update
        if @resource.typus_user_id? && admin_user.is_not_root?
          @item.update_attributes(Typus.user_foreign_key => admin_user.id)
        end
      end

    end
  end
end
