module Octopress
  module Ink
    module Commands
      class New
        def self.process_command(p)
          p.command(:new) do |c|
            c.syntax "new <PLUGIN_NAME> [options]"
            c.description "Create a new Octopress Ink plugin with Ruby gem scaffolding."
            c.option "path", "--path PATH", "Create a plugin at a specified path (defaults to current directory)."
            c.option "theme", "--theme", "Create a new theme."

            c.action do |args, options|
              if args.empty?
                raise "Please provide a plugin name, e.g. my_awesome_plugin."
              else
                options['name'] = args[0]
                @options = options
                new_plugin
              end
            end
          end
        end

        def self.new_plugin
          path = @options['path'] ||= Dir.pwd
          gem_name = @options['name']

          @gem_dir = File.join(path, gem_name)
          @gemspec_file = "#{gem_name}/#{gem_name}.gemspec"

          if !Dir.exist?(path)
            raise "Directory not found: #{File.expand_path(path)}."
          end

          if !Dir["#{@gem_dir}/*"].empty?
            raise "Directory not empty: #{File.expand_path(@gem_dir)}."
          end

          FileUtils.cd path do
            create_gem
            add_dependency
            add_plugin
            add_asset_dirs
            add_demo_files
          end
        end

        def self.create_gem
          begin
            require 'bundler/cli'
            bundler = Bundler::CLI.new
          rescue LoadError
            raise "To use this feautre you'll need to install the bundler gem with `gem install bundler`."
          end

          bundler.gem(@options['name'])
        end

        # Add Octopress Ink dependency to Gemspec
        #
        def self.add_dependency
          minor_version = VERSION.scan(/\d\.\d/)[0]
          @gemspec = File.open(@gemspec_file).read
          dependency  = "  spec.add_runtime_dependency 'octopress-ink', '~> #{minor_version}', '>= #{VERSION}'\n"
          dependency += "\n  spec.add_development_dependency 'octopress'\n"

          pos = @gemspec.index("  spec.add_development_dependency")
          @gemspec = insert_before(@gemspec, pos, dependency)

          File.open(@gemspec_file, 'w+') {|f| f.write(@gemspec) }
        end

        # Add Octopress Ink plugin to core module file
        #
        def self.add_plugin
          # Grab the module directory from the version.rb require.
          # If a gem is created with dashes e.g. "some-gem", Bundler puts the module file at lib/some/gem.rb
          module_subpath = @gemspec.scan(/['"](.+)\/version['"]/).flatten[0]
          @module_file = File.join(@options['name'], 'lib', "#{module_subpath}.rb")
          mod = File.open(@module_file).read
          
          # Find the inner most module name
          @modules  = mod.scan(/module\s+(.+?)\n/).flatten
          @mod_path = @modules.join('::')
          
          mod = add_simple_plugin mod

          File.open(@module_file, 'w+') {|f| f.write(mod) }
        end

        def self.add_asset_dirs
          %w{images fonts pages files layouts includes stylesheets javascripts}.each do |asset|
            dir = File.join(@options['name'], 'assets', asset)
            FileUtils.mkdir_p dir
          end
        end

        # New plugin uses a simple configuration hash
        #
        def self.add_simple_plugin(mod)
          mod  = mod.scan(/require.+\n/)[0]
          mod += 'require "octopress-ink"'
          mod += "\n\nOctopress::Ink.new_plugin({\n#{indent(plugin_config)}\n})"
        end

        def self.plugin_config
          plugin_name = format_name(@modules.last)
          plugin_slug = Filters.sluggify(@options['name'])
          depth = @module_file.count('/') - 1
          assets_path = ("../" * depth) + 'assets'
          type = @options['theme'] ? 'theme' : 'plugin'

          config = <<-HERE
name:          "#{plugin_name}",
slug:          "#{plugin_slug}",
assets_path:   File.expand_path(File.join(File.dirname(__FILE__), "#{assets_path}")),
type:          "#{type}",
version:       #{@mod_path}::VERSION,
description:   "",
website:       ""
          HERE
          config.rstrip
        end

        def self.add_demo_files
          dir = File.join(@options['name'], 'demo')
          Jekyll::Commands::New.process([dir], {blank: true})

          gemfile = <<-HERE
source 'https://rubygems.org'

group :octopress do
  gem 'octopress'
  gem '#{@options['name']}', path: '../'
end
          HERE

          File.open(File.join(dir, 'Gemfile'), 'w+') {|f| f.write(gemfile) }
        end

        def self.indent(input, level=1)
          input.gsub(/^/, '  ' * level)
        end
        # Add spaces between capital letters
        #
        def self.format_name(name)
          name.scan(/.*?[a-z](?=[A-Z]|$)/).join(' ')
        end

        def self.insert_before(str, pos, input)
          if pos
            str[0..(pos - 1)] + input + str[pos..-1]
          else
            str
          end
        end
      end
    end
  end
end