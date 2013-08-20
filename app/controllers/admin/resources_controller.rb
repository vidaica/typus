class Admin::ResourcesController < Admin::BaseController

  include Typus::Controller::Navigation
  include Typus::Controller::Actions
  include Typus::Controller::Filters
  include Typus::Controller::Format
  include Typus::Controller::Headless

  Whitelist = [:edit, :update, :destroy, :toggle]

  before_filter :get_model
  before_filter :set_context
  before_filter :get_object, :only => Whitelist + [:show]
  before_filter :check_resource_ownership, :only => Whitelist
  before_filter :check_if_user_can_perform_action_on_resources

  def index
    get_objects

    custom_actions_for(:index).each do |action|
      prepend_resources_action(action.titleize, {:action => action, :id => nil})
    end

    respond_to do |format|
      format.html do
        set_default_action
        add_resource_action("Destroy", {:action => "destroy"}, { :data => { :confirm => "#{Typus::I18n.t("Trash")}?" }, :method => 'delete'})
        get_paginated_data
      end

      format.csv { generate_csv }
      format.json { export(:json) }
      format.xml { export(:xml) }
    end
  end

  def new
    @item = @resource.new(params[:resource], mass_assignment_settings)

    respond_to do |format|
      format.html
      format.json { render :json => @item }
    end
  end

  def create
    # Note that we still can still assign the item to another model. To change
    # this behavior we need only to change how we merge the params.
    item_params = params[:resource] || {}
    item_params.merge!(params[@object_name])

    @item = @resource.new
    @item.assign_attributes(item_params, mass_assignment_settings)

    set_attributes_on_create

    respond_to do |format|
      if @item.save
        format.html { redirect_on_success }
        format.json { render :json => @item, :status => :created, :location => @item }
      else
        format.html { render :action => "new" }
        format.json { render :json => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def edit
    custom_actions_for(:edit).each do |action|
      prepend_resources_action(action.titleize, {:action => action, :id => @item})
    end
  end

  def show
    check_resource_ownership if @resource.typus_options_for(:only_user_items)

    if admin_user.can?('edit', @resource)
      prepend_resources_action("Edit", {:action => 'edit', :id => @item})
    end

    custom_actions_for(:show).each do |action|
      prepend_resources_action(action.titleize, {:action => action, :id => @item})
    end

    respond_to do |format|
      format.html
      format.xml { render :xml => @item }
      format.json { render :json => @item }
    end
  end

  def update
    attributes = params[:_nullify] ? { params[:_nullify] => nil } : params[@object_name]

    respond_to do |format|
      if @item.update_attributes(attributes, mass_assignment_settings)
        set_attributes_on_update
        format.html { redirect_on_success }
        format.json { render :json => @item }
      else
        format.html { render :edit }
        format.json { render :json => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    if @item.destroy
      notice = Typus::I18n.t("%{model} successfully removed.", :model => @resource.model_name.human)
    else
      alert = @item.errors.full_messages
    end
    redirect_to :back, :notice => notice, :alert => alert
  end

  def toggle
    @item.toggle(params[:field])

    respond_to do |format|
      if @item.save
        format.html do
          notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
          redirect_to :back, :notice => notice
        end
        format.json { render :json => @item }
      else
        format.html { render :edit }
        format.json { render :json => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  private

  def get_model
    @resource = resource
    @object_name = ActiveModel::Naming.singular(@resource)
  end

  def resource
    params[:controller].extract_class
  rescue
    params[:controller].extract_singular_class
  end
  helper_method :resource

  def set_context
    @resource
  end
  helper_method :set_context

  def get_object
    @item = @resource.find(params[:id])
  end

  def get_objects
    set_scope
    set_wheres
    set_joins
    check_resources_ownership if @resource.typus_options_for(:only_user_items)
    set_order if @resource.respond_to?(:order)
    set_eager_loading
  end

  def fields
    @resource.typus_fields_for(params[:action])
  end
  helper_method :fields

  def set_scope
    return unless params[:scope]

    if @resource.typus_scopes.include?(params[:scope])
      @resource = @resource.send(params[:scope])
    else
      not_allowed("Requested scope not defined on your whitelist.")
    end
  end

  def set_wheres
           
    session[@object_name] = {} if ! session[@object_name] or params[:reset_filter] == '1'          
    conditions = (session[@object_name][:conditions] || {}).merge(params)
    session[@object_name][:conditions] = conditions
            
    @resource.build_conditions(conditions).each do |condition|
      @resource = @resource.where(condition)
    end
    
  end

  def set_joins
    @resource.build_my_joins(params).each do |join|
      @resource = @resource.joins(join)
    end
  end

  def set_order
    params[:sort_order] ||= "desc"

    if (order = params[:order_by] ? "#{params[:order_by]} #{params[:sort_order]}" : @resource.typus_order_by).present?
      @resource = @resource.order(order)
    end
  end

  def set_eager_loading
    if (eager_loading = @resource.reflect_on_all_associations(:belongs_to).reject { |i| i.options[:polymorphic] }.map(&:name)).any?
      @resource = @resource.includes(eager_loading)
    end
  end

  def redirect_on_success
    path = params.dup.cleanup

    options = if params[:_addanother]
      { :action => 'new', :id => nil }
    elsif params[:_continue]
      { :action => 'edit', :id => @item.id }
    else
      { :action => nil, :id => nil }
    end

    message = params[:action].eql?('create') ? "%{model} successfully created." : "%{model} successfully updated."
    notice = Typus::I18n.t(message, :model => @resource.model_name.human)

    redirect_to path.merge!(options).compact, :notice => notice
  end

  def set_default_action
    default_action = @resource.typus_options_for(:default_action_on_item)
    action = admin_user.can?('edit', @resource.model_name) ? default_action : "show"
    prepend_resource_action(action.titleize, {:action => action})
  end

  def custom_actions_for(action)
    return [] if headless_mode?
    @resource.typus_actions_on(action).reject { |a| admin_user.cannot?(a, @resource.model_name) }
  end

  # Detect accessible attributes for the current role. If the current role
  # does not have accessible attributes we will use the default role.
  #
  # We also detect if we need protection or not. If we do not set any
  # accessible attribute we still want to be able to use Typus, in such
  # case we will disable the protection.
  def mass_assignment_settings
    {
      :as => @resource.accessible_attributes_role_for(current_role),
      :without_protection => @resource.without_protection?(current_role),
    }
  end

end
