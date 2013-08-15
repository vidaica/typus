# Module designed to work with `acts_as_list`.
module Typus
  module Controller
    module ActsAsList

      def self.included(base)
        base.before_filter :get_object, :only => [:position] + base::Whitelist + [:show]
        base.before_filter :check_resource_ownership, :only => [:position] + base::Whitelist
      end

      def position
        if %w(move_to_top move_higher move_lower move_to_bottom).include?(params[:go])
          @item.send(params[:go])
          notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
          redirect_to :back, :notice => notice
        else
          not_allowed
        end
      end

    end
  end
end
