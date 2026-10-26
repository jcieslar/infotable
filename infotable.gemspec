require_relative "lib/infotable/version"

Gem::Specification.new do |spec|
  spec.name        = "infotable"
  spec.version     = Infotable::VERSION
  spec.authors     = [ "Jakub Cieślar" ]
  spec.email       = [ "jakub@infovation.pl" ]
  spec.homepage    = "https://infotable.infovation.eu/"
  spec.summary     = "Modern, flexible datatable engine for Rails 8+ with Hotwire"
  spec.description = "InfoTable provides server-side datatable functionality with filtering, sorting, searching, and pagination. Built with Hotwire, Stimulus, and Tailwind CSS for a modern, no-reload user experience."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3" # Pagy 43

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jcieslar/infotable"
  spec.metadata["changelog_uri"] = "https://github.com/jcieslar/infotable/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib,exe}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.bindir = "exe"
  spec.executables = [ "infotable-mcp" ]

  # Rails and core dependencies
  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "csv" # CSV export; no longer a default gem in Ruby 3.4+

  # Hotwire stack
  spec.add_dependency "turbo-rails", "~> 2.0"
  spec.add_dependency "stimulus-rails", "~> 1.3"

  # Pagination
  spec.add_dependency "pagy", "~> 43.0"

  # Development dependencies
  spec.add_development_dependency "pg"
  spec.add_development_dependency "puma"
  spec.add_development_dependency "propshaft"
  spec.add_development_dependency "mcp" # exe/infotable-mcp (optional in host apps)
end
