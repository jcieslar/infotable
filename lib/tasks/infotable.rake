namespace :infotable do
  desc "Generate infotable.css from ERB template with resolved gem paths"
  task generate_tailwind_sources: :environment do
    # Find the ERB template
    erb_path = if File.exist?("app/assets/stylesheets/infotable.css.erb")
      "app/assets/stylesheets/infotable.css.erb"
    elsif File.exist?("app/assets/tailwind/infotable.css.erb")
      "app/assets/tailwind/infotable.css.erb"
    else
      puts "⚠️  infotable.css.erb not found. Run 'rails generate infotable:install' first."
      next
    end

    output_path = erb_path.sub(".erb", "")

    # Read and process the ERB template
    require "erb"
    template = File.read(erb_path)
    result = ERB.new(template).result(binding)

    # Write the generated CSS
    File.write(output_path, result)

    puts "✅ Generated #{output_path} from ERB template"
    puts "   Views: #{Infotable.views_path}"
    puts "   Formatters: #{Infotable.formatters_path}"
  end

  # Alias for backwards compatibility
  task update_tailwind_paths: :generate_tailwind_sources

  desc "Display InfoTable gem paths for Tailwind CSS (for debugging)"
  task show_tailwind_paths: :environment do
    puts "\n" + "=" * 60
    puts "InfoTable Gem Paths"
    puts "=" * 60
    puts "Gem root:        #{Infotable.root}"
    puts "Views path:      #{Infotable.views_path}"
    puts "Formatters path: #{Infotable.formatters_path}"
    puts "=" * 60 + "\n"
  end
end

# Hook into Tailwind CSS build tasks
if Rake::Task.task_defined?("tailwindcss:build")
  Rake::Task["tailwindcss:build"].enhance([ "infotable:generate_tailwind_sources" ])
end

if Rake::Task.task_defined?("tailwindcss:watch")
  Rake::Task["tailwindcss:watch"].enhance([ "infotable:generate_tailwind_sources" ])
end

if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance([ "infotable:generate_tailwind_sources" ])
end
