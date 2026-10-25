require "test_helper"
require "rails/generators/test_case"
require "generators/infotable/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Infotable::Generators::InstallGenerator
  destination File.expand_path("../tmp/generator", __dir__)

  setup do
    prepare_destination
    write "config/routes.rb", "Rails.application.routes.draw do\nend\n"
    write "app/assets/tailwind/application.css", "@import \"tailwindcss\";\n"
  end

  # The generator looks for files relative to the working directory
  def run_generator(*)
    Dir.chdir(destination_root) { super }
  end

  def write(path, content = "")
    full = File.join(destination_root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def read(path) = File.read(File.join(destination_root, path))

  test "mounts the engine, creates app/infotable and the initializer" do
    run_generator

    assert_file "config/routes.rb", %r{mount Infotable::Engine => "/infotable"}
    assert_file "app/infotable/.keep"
    assert_file "config/initializers/infotable.rb", /Infotable\.configure/
  end

  test "initializer only sets options that exist" do
    run_generator

    assert_file "config/initializers/infotable.rb" do |content|
      code = content.gsub(/^\s*#.*$/, "")
      assert_no_match(/turbo_enabled|pagination_gem|config\.theme\b/, code)
      %w[default_per_page per_page_options drawer_position drawer_width autofilter].each do |option|
        assert_match(/config\.#{option} =/, code)
      end
    end
  end

  test "generated initializer loads against the configuration" do
    run_generator

    Infotable.reset_configuration!
    load File.join(destination_root, "config/initializers/infotable.rb")
    assert_equal 25, Infotable.configuration.default_per_page
    assert_equal "26rem", Infotable.configuration.drawer_width
  ensure
    Infotable.reset_configuration!
  end

  test "writes the Tailwind sources file with dynamic gem paths" do
    run_generator

    assert_file "app/assets/tailwind/infotable.css.erb" do |content|
      assert_match(/Infotable\.views_path/, content)
      assert_match(/Infotable\.formatters_path/, content)
    end
  end

  test "imports the generated sources into the Tailwind entry file" do
    run_generator

    assert_file "app/assets/tailwind/application.css", /@import "tailwindcss";.*@import '\.\/infotable';/m
  end

  test "does not import the sources twice" do
    run_generator
    run_generator

    assert_equal 1, read("app/assets/tailwind/application.css").scan("@import './infotable'").size
  end

  test "installs an executable sync script for vendored gems" do
    run_generator

    path = File.join(destination_root, "bin/sync-infotable-gem.sh")
    assert File.executable?(path)
    assert_match(/rsync/, File.read(path))
  end

  test "gitignores the generated stylesheet" do
    write ".gitignore", "/log\n"
    run_generator

    assert_file ".gitignore", %r{app/assets/tailwind/infotable\.css}
  end

  test "does not duplicate the gitignore entry when run twice" do
    run_generator
    run_generator

    assert_equal 1, read(".gitignore").scan("app/assets/tailwind/infotable.css\n").size
  end

  test "detects importmap" do
    write "config/importmap.rb"

    assert_match(/Detected JavaScript bundler: importmap/, run_generator)
  end

  test "registers both controllers for esbuild setups" do
    set_up_esbuild
    run_generator

    assert_file "app/javascript/controllers/index.js" do |content|
      assert_match(/register\("infotable--table"/, content)
      assert_match(/register\("infotable--drawer"/, content)
    end
  end

  test "does not register the controllers twice" do
    set_up_esbuild
    run_generator
    run_generator

    assert_equal 1, read("app/javascript/controllers/index.js").scan('register("infotable--table"').size
  end

  test "stops with a hint when Tailwind is not installed" do
    FileUtils.rm_rf(File.join(destination_root, "app/assets/tailwind"))

    assert_raises(SystemExit) { capture(:stdout) { run_generator } }
  end

  def set_up_esbuild
    write "app/javascript/controllers/index.js", "import { application } from \"./application\"\n"
    write "esbuild.config.js"
    write "package.json", %({"dependencies":{"@hotwired/stimulus":"3","@hotwired/turbo-rails":"8","sortablejs":"1"}})
  end

  test "the controllers the generator registers exist in the engine" do
    root = File.expand_path("../../app/assets/javascripts/infotable/controllers", __dir__)
    %w[table_controller drawer_controller].each { assert File.exist?("#{root}/#{_1}.js"), "#{_1}.js missing" }
  end
end
