module Admin::BaseHelper

  def admin_header
    render "helpers/admin/base/header", { :admin_title => admin_title }
  end

  def admin_title(page_title = nil)
    if page_title
      content_for(:title) { page_title }
    else
      setting = defined?(Admin::Setting) && Admin::Setting.admin_title
      setting || Typus.admin_title
    end
  end

  def admin_apps
    render "helpers/admin/base/apps"
  end

  def admin_login_info
    render "helpers/admin/base/login_info" unless admin_user.is_a?(FakeUser)
  end

  def admin_sign_out_path
    case Typus.authentication
    when :devise
      send("destroy_#{Typus.user_class_name.underscore}_session_path")
    else
      destroy_admin_session_path
    end
  end

  def admin_edit_user_path(user)
    { :controller => "/admin/#{Typus.user_class.to_resource}",
      :action => "edit",
      :id => user.id }
  end

  def admin_display_flash_message
    if flash.any?
      String.new.tap do |html|
        flash.each do |type, message|
          html << content_tag(:div, message, :id => 'flash', :class => "alert alert-#{type}")
        end
      end.html_safe
    end
  end

  def set_modal_options_for(klass)
    { "data-toggle" => "modal",
      "data-controls-modal" => "modal-from-dom-#{klass.to_resource}",
      "data-backdrop" => "true",
      "data-keyboard" => "true",
      "class" => "ajax-modal",
      "url" => "override-this" }
  end

  def body_class
    if params[:controller] == 'admin/dashboard'
      "base dashboard #{params[:action].parameterize}"
    else
      "base #{@resource.model_name.human.parameterize} #{params[:action].parameterize}"
    end
  end

end
