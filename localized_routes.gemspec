Gem::Specification.new do |s|
  s.name = "localized_routes"
  s.version = "0.1"
  s.author = "José Ignacio Fernández"
  s.email = "joseignacio.fernandez@gmail.com"
  s.homepage = ""
  s.summary = "Route localization made simple"
  s.description = "This plugin allows translating routes by simply installing and adding translations to each locale. Works with Rails 3."

  s.add_dependency('i18n', '> 0.3.5')

  s.files = Dir["{lib,spec}/**/*", "[A-Z]*", "init.rb"]
  s.require_path = "lib"

  s.required_rubygems_version = ">= 1.3.4"
end