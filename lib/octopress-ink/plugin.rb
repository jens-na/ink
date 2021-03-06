require 'find'

module Octopress
  module Ink
    class Plugin

      DEFAULT_CONFIG = {
        type: 'plugin'
      }

      attr_reader   :name, :type, :assets_path, :local, :website, :description, :version,
                    :layouts_dir, :stylesheets_dir, :javascripts_dir, :files_dir, :includes_dir, :images_dir,
                    :layouts, :includes, :images, :fonts, :files, :pages, :docs

      def initialize(options)
        options = Jekyll::Utils.symbolize_hash_keys(options || configuration)

        DEFAULT_CONFIG.merge(options).each { |k,v| set_config(k,v) }

        @layouts_dir       = 'layouts'
        @files_dir         = 'files'
        @pages_dir         = 'pages'
        @docs_dir          = 'docs'
        @fonts_dir         = 'fonts'
        @images_dir        = 'images'
        @includes_dir      = 'includes'
        @javascripts_dir   = 'javascripts'
        @stylesheets_dir   = 'stylesheets'
        @config_file       = 'config.yml'
        @layouts           = []
        @includes          = []
        @css               = []
        @js                = []
        @coffee            = []
        @images            = []
        @sass              = []
        @docs              = []
        @fonts             = []
        @files             = []
        @pages             = []
        @slug            ||= @name
      end

      def register
        unless @assets_path.nil?
          disable_assets
          add_assets
          add_layouts
          add_includes
          add_javascripts
          add_fonts
          add_images
          add_docs
          add_files
          add_pages
          add_stylesheets
        end
      end

      # Themes should always have the slug "theme"
      #
      def slug
        Filters.sluggify @type == 'theme' ? 'theme' : @slug
      end

      # Path where doc pages will be hosted
      #
      # - returns: String, eg: docs/plugins/plugin-slug
      #
      def docs_base_path

        if @type == 'theme'
          base = 'theme'
        else
          base = File.join('plugins', slug)
        end

        File.join('docs', base)
      end

      # Docs pages for easy listing in an index
      #
      # returns: Array of hashes including doc page title and url
      #
      def doc_pages
        if !@docs.empty?
          @doc_pages ||= @docs.clone.map { |d|
            page = d.page
            title   = page.data['link_title'] || page.data['title'] || page.basename
            url = File.join('/', docs_base_path, page.url.sub('index.html', ''))

            {
              'title' => title,
              'url' => url
            }
          }.sort_by { |i| 
            # Sort by depth of url
            i['url'].split('/').size
          }
        end
      end

      # List info about plugin's assets
      #
      # returs: String filled with asset info
      #
      def list(options={})
        if options['minimal']
          minimal_list
        else
          detailed_list(options)
        end
      end

      # Add asset files which aren't disabled
      #
      def add_asset_files(options)
        select_assets(options).each do |name, assets|
          next if name == 'defaults'
          assets.each {|file| file.add unless file.disabled? }
        end
      end

      # Copy asset files to plugin override path
      #
      def copy_asset_files(path, options)
        copied = []

        select_assets(options).each do |name, assets|
          next if name == 'docs'
          assets.each { |a| copied << a.copy(path) }
        end
        copied
      end

      # stylesheets should include Sass and CSS
      #
      def stylesheets
        css.clone.concat sass_without_partials
      end

      def javascripts
        js.clone.concat coffee
      end

      # Plugin configuration
      #
      # returns: Hash of merged user and default config.yml files
      #
      def config
        @config ||= defaults.read
      end

      # Remove files from Jekyll since they'll be proccessed by Ink instead
      #
      def remove_jekyll_assets(files)
        files.each {|f| f.remove_jekyll_asset }
      end

      def include(file)
        @includes.find{|i| i.filename == file }.path
      end

      private

      def get_paths(files)
        files.dup.map { |f| f.path }.compact
      end

      def disable_assets
        disabled = []
        config['disable'] ||= {}
        config['disable'].each do |key,val| 
          next unless can_disable.include? key
          if !!val == val
            disabled << key if val
          elsif val.is_a? Array
            val.each { |v| disabled << File.join(key, v) }
          elsif val.is_a? String
            disabled << File.join(key, val)
          end
        end
        config['disable'] = disabled
      end

      def defaults
        @defaults ||= Assets::Config.new(self, @config_file)
      end


      def can_disable
        [ 
          'pages',
          'sass',
          'css',
          'stylesheets',
          'javascripts',
          'js',
          'coffee',
          'images',
          'fonts',
          'files'
        ]
      end

      def assets
        {
          'docs'        => @docs,
          'layouts'     => @layouts,
          'includes'    => @includes,
          'pages'       => @pages, 
          'sass'        => @sass, 
          'css'         => @css,
          'js'          => @js, 
          'coffee'      => @coffee, 
          'images'      => @images, 
          'fonts'       => @fonts, 
          'files'       => @files,
          'defaults'    => [@defaults]
        }
      end
      
      # Return information about each asset 
      def assets_list(options)
        message = ''
        no_assets = []

        select_assets(options).each do |name, assets|
          next if assets.compact.size == 0

          case name
          when 'docs'
            header = "documentation: /#{docs_base_path}/"
            message += asset_list(assets, header)
          when 'defaults'
            message += asset_list(assets, 'default configuration')
          else
            message += asset_list(assets, name)
          end

          message += "\n"
        end

        message
      end

      def asset_list(assets, heading)
        list = " #{heading}:\n"
        assets.each do |asset|
          list += "#{asset.info}\n"
        end

        list
      end

      def minimal_list
        message = " #{@name}"
        message += " (#{slug})"
        message += " - v#{@version}" if @version
        if @description && !@description.empty?
          message = "#{message.ljust(30)} - #{@description}"
        end
        message += "\n"
      end

      def detailed_list(options)
        list = assets_list(options)
        return '' if list.empty?

        name = "Plugin: #{@name}"
        name += " (theme)" if @type == 'theme'
        name += " - v#{@version}" if @version
        name  = name
        message = name
        message += "\nSlug: #{slug}"

        if @description && !@description.empty?
          message += "\n#{@description}"
        end

        if @website && !@website.empty?
          message += "\n#{@website}"
        end

        lines = ''
        80.times { lines += '=' }

        message = "\n#{message}\n#{lines}\n"
        message += list
        message += "\n"
      end

      def pad_line(line)
        line = "| #{line.ljust(76)} |"
      end

      # Return selected assets
      #
      # input: options (an array ['type',...], hash {'type'=>true}
      # or string of asset types)
      # 
      # Output a hash of assets instances {'files' => @files }
      #
      def select_assets(asset_types)

        # Accept options from the CLI (as a hash of asset_name: true)
        # Or from Ink modules as an array of asset names
        #
        if asset_types.is_a? Hash
           
          # Show Sass and CSS when 'stylesheets' is chosen
          if asset_types['stylesheets']
            asset_types['css'] = true
            asset_types['sass'] = true
            asset_types.delete('stylesheets')
          end

          if asset_types['javascripts']
            asset_types['js'] = true
            asset_types['coffee'] = true
            asset_types.delete('javascripts')
          end

          asset_types = asset_types.keys
        end

        # Args should allow a single asset as a string too
        #
        if asset_types.is_a? String
          asset_types = [asset_types] 
        end
        
        # Match asset_types against list of assets and
        # remove asset_types which don't belong
        #
        asset_types.select!{|asset| assets.include?(asset)}

        # If there are no asset_types, return all assets
        # This will happen if list command is used with
        # no filtering arguments
        #
        if asset_types.nil? || asset_types.empty?
          assets
        else
          assets.select{|k,v| asset_types.include?(k)}
        end
      end

      def add_stylesheets
        find_assets(@stylesheets_dir).each do |asset|
          if File.extname(asset) =~ /s[ca]ss/
            @sass << Assets::Sass.new(self, @stylesheets_dir, asset)
          else
            @css << Assets::Stylesheet.new(self, @stylesheets_dir, asset)
          end
        end
      end

      def add_layouts
        @layouts = add_new_assets(@layouts_dir, Assets::Layout)
      end

      def add_includes
        @includes = add_new_assets(@includes_dir, Assets::Asset)
      end

      def add_pages
        @pages = add_new_assets(@pages_dir, Assets::PageAsset)
      end

      def add_docs
        find_assets(@docs_dir).each do |asset|
          unless asset =~ /^_/
            @docs << Assets::DocPageAsset.new(self, @docs_dir, asset)
          end
        end
      end

      def add_files
        @files = add_new_assets(@files_dir, Assets::FileAsset)
      end

      def add_javascripts
        find_assets(@javascripts_dir).each do |asset|
          if File.extname(asset) =~ /\.js$/
            @js << Assets::Javascript.new(self, @javascripts_dir, asset)
          elsif File.extname(asset) =~ /\.coffee$/
            @coffee << Assets::Coffeescript.new(self, @javascripts_dir, asset)
          end
        end
      end

      def add_fonts
        @fonts = add_new_assets(@fonts_dir, Assets::Asset)
      end

      def add_images
        @images = add_new_assets(@images_dir, Assets::Asset)
      end

      def add_new_assets(dir, asset_type)
        find_assets(dir).map do |asset|
          asset_type.new(self, dir, asset)
        end
      end

      def find_assets(dir)
        full_dir = File.join(@assets_path, dir)
        glob_assets(full_dir).map do |file|
          file.sub(full_dir+'/', '')
        end
      end

      def glob_assets(dir)
        return [] unless Dir.exist? dir
        Find.find(dir).to_a.reject {|f| File.directory? f }
      end

      def css
        @css.reject{|f| f.disabled? }.compact
      end

      def sass
        @sass.reject{|f| f.disabled? }.compact
      end

      def sass_without_partials
        sass.reject{|f| f.file =~ /^_/ }
      end

      def js
        @js.reject{|f| f.disabled? }.compact
      end

      def coffee
        @coffee.reject{|f| f.disabled? }.compact
      end

      def configuration; {}; end

      def set_config(name, value)
        instance_variable_set("@#{name}", value)
        instance_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{name}
            @#{name}
          end
        EOS
      end

      def add_assets; end

    end
  end
end
