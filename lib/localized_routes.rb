module LocalizedRoutes
  module Routing
    def add_route_with_i18n(app, conditions = {}, requirements = {}, defaults = {}, name = nil, anchor = true)
      if defaults[:controller] == "rails/info" or defaults[:i18n]==false
        # Ignore localization
        add_route_without_i18n(app, conditions, requirements, defaults, name, anchor)
      else
        # Allow setting locale as default route parameter
        valid_conditions.push :locale unless valid_conditions.include?(:locale)
      
        # Create route for each locale
        I18n.available_locales.each do |locale|
          path = conditions[:path_info]

          # Translate the static chunks of the route
          chunks = path.split(/[\/\(\)]/).reject {|c| c == "" or c =~ /[:\.]/ }
          chunks.sort_by{|c| -c.size}.each { |c| path = path.gsub("/#{c}", "/" + I18n.translate("routes.#{c}", :locale=>locale, :default=>c)) }
        
          new_path = "/#{locale}#{is_root?(path) ? '' : path}"

          add_route_without_i18n(app, conditions.merge(:path_info=>new_path), requirements, defaults.merge(:locale=>locale.to_s), "#{name}_#{locale}", anchor)
        end
      
        # Add helpers such as posts_path, that use posts_es_path, posts_en_path, ...
        if is_root? conditions[:path_info]
          add_route_without_i18n(app, conditions, requirements, defaults, nil, anchor)
          add_root_helper_path name
        else
          add_helper_path name
        end
      end
    end
  
    private
    def is_root? path
      ['/', '/(.:format)'].include? path
    end
    
    def add_helper_path old_name
      # Taken from translate_routes
      ['path', 'url'].each do |suffix|
        new_helper_name = "#{old_name}_#{suffix}"
        def_new_helper = <<-DEF_NEW_HELPER
          def #{new_helper_name}(*args)
            send("#{old_name}_\#{I18n.locale.to_s.underscore}_#{suffix}", *args)
          end
        DEF_NEW_HELPER

        ActionDispatch::Routing::UrlFor.module_eval(def_new_helper)
        Rails.application.routes.named_routes.helpers << new_helper_name.to_sym
      end
    end

    def add_root_helper_path old_name
      # Taken from translate_routes
      ['path', 'url'].each do |suffix|
        new_helper_name = "#{old_name}_#{suffix}"
        def_new_helper = <<-DEF_NEW_HELPER
          def #{new_helper_name}(args={})
            result = send("#{old_name}_\#{I18n.locale.to_s.underscore}_#{suffix}", args.reject{|k,v| k.to_s=='locale'})
            if args.include?(:locale) and args[:locale].nil?
              result = result.split('/')[0..2] * '/' +  '/'
            end
            result
          end
        DEF_NEW_HELPER

        ActionDispatch::Routing::UrlFor.module_eval(def_new_helper)
        Rails.application.routes.named_routes.helpers << new_helper_name.to_sym
      end
    end
  end
  
  module Controller
    def self.included base
      base.class_eval { before_filter :get_locale }
    end
    
    def get_locale
      # Get locale from the params, obtained from the path
      I18n.locale = params[:locale] || I18n.default_locale

      # Next is an educated guess - emails should have recipient's locale
      ActionMailer::Base.default_url_options[:locale] = I18n.locale
    end
    
    def default_url_options
      {:locale => I18n.locale.to_s}
    end
  end
  
  module Test
    def self.included base
      base.class_eval { alias_method_chain :process, :default_locale }
    end
    
    def process_with_default_locale(action, parameters = nil, session = nil, flash = nil, http_method = 'GET')
      parameters = {:locale=>I18n.locale.to_s}.merge(parameters||{})
      process_without_default_locale(action, parameters, session = nil, flash = nil, http_method)
    end
  end
end

# Include the stuff
ActionDispatch::Routing::RouteSet.send :include, LocalizedRoutes::Routing
ActionDispatch::Routing::RouteSet.send :alias_method_chain, :add_route, :i18n
ActionController::Base.send :include, LocalizedRoutes::Controller
ActionController::TestCase.send :include, LocalizedRoutes::Test

# Load translations
if defined?(Rails) and Rails.respond_to?(:root) and Rails.root
  I18n.load_path = (I18n.load_path << Dir[Rails.root.join('config', 'locales', '*.yml').to_s]).flatten.uniq
end