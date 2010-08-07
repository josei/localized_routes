module LocalizedRoutes
  def add_route_with_i18n(app, conditions = {}, requirements = {}, defaults = {}, name = nil, anchor = true)
    if defaults[:controller] == "rails/info"
      # Ignore this special case
      add_route_without_i18n(app, conditions, requirements, defaults, name, anchor)
    else
      # Create route for each locale
      I18n.available_locales.each do |locale|
        path = conditions[:path_info]

        # Translate the static chunks of the route
        chunks = path.split(/[\/\(\)]/).reject {|c| c == "" or c =~ /[:\.]/ }
        chunks.sort_by{|c| -c.size}.each { |c| path = path.gsub("/#{c}", "/" + I18n.translate("routes.#{c}", :locale=>locale, :default=>c)) }
        
        new_path = "/:locale#{path=='/' ? '' : path}"
        
        add_route_without_i18n(app, conditions.merge(:path_info=>new_path), requirements, defaults, "#{name}_#{locale}", anchor)
      end
      add_route_without_i18n(app, conditions, requirements, defaults, nil, anchor) if conditions[:path_info] == '/'
      
      # Add helpers such as posts_path, that use posts_es_path, posts_en_path, ...
      add_helper_path name
    end
  end
  
  private
  def add_helper_path old_name
    # Taken from translate_routes
    ['path', 'url'].each do |suffix|
      new_helper_name = "#{old_name}_#{suffix}"
      def_new_helper = <<-DEF_NEW_HELPER
        def #{new_helper_name}(*args)
          send("#{old_name}_\#{I18n.locale.to_s.underscore}_#{suffix}", *args)
        end
      DEF_NEW_HELPER

      [ActionController::Base, ActionView::Base, ActionMailer::Base, ActionDispatch::Integration::Session].each { |d| d.module_eval(def_new_helper) }
      Rails.application.routes.named_routes.helpers << new_helper_name.to_sym
    end
  end
  
  module Controller
    def self.included base
      base.class_eval { before_filter :get_locale }
    end
    
    def get_locale
      I18n.locale = params[:locale] || I18n.default_locale
      raise ActionController::RoutingError, 'Invalid locale' unless I18n.available_locales.include?(I18n.locale)
    end
    
    def default_url_options(options={})
      {:locale => I18n.locale}
    end
  end
end

ActionDispatch::Routing::RouteSet.send :include, LocalizedRoutes
ActionDispatch::Routing::RouteSet.send :alias_method_chain, :add_route, :i18n

if defined?(Rails) and Rails.respond_to?(:root) and Rails.root
  I18n.load_path = (I18n.load_path << Dir[Rails.root.join('config', 'locales', '*.yml').to_s]).flatten.uniq
end