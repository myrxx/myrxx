$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "myrxx/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "myrxx"
  s.version     = Myrxx::VERSION
  s.authors     = ["MyRxX.com"]
  s.email       = ["support@myrxx.com"]
  s.homepage    = "http://myrxx.com"
  s.summary     = "API for managing patients and prescribing workouts within the MyRxX.com site"
  s.description = "Full documentation available. Contact support@myrxx.com for details"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.0"
  s.add_dependency "oauth2"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "autotest-rails"
end
