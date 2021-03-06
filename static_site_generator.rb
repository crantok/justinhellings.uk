
require 'fileutils'
require 'pathname'
require 'yaml'

class StaticSiteGenerator

  # +template_processor+ must fulfil
  # * process_template ( template_content [String], site_metadata [Hash] ) -> template [client-defined object]
  # +content_processor+ must fulfil
  # * :content_file? ( filename ) -> [Boolean]
  # * :process_content ( content [String], template [client-defined object], file_metadata [Hash] ) -> html [String]
  # Clients may of course supply the same object to fulfil both interfaces.
  def initialize template_processor, content_processor
    check_interface :template_processor, template_processor, :process_template
    check_interface :content_processor, content_processor, :content_file?
    check_interface :content_processor, content_processor, :process_content
    @content_processor = content_processor
    @template_processor = template_processor
  end

  # Generate a website in +output_dir+ from the contents of +input_dir+ and
  # +templates_dir+
  def generate input_dir, output_dir, templates_dir

    backup_output_directory(output_dir)
    metadata = read_input_directory(input_dir)
    create_tree_and_copy_assets(metadata, input_dir, output_dir)
    inflate_content(metadata, metadata, input_dir, output_dir, templates_dir)

    # Return metadata, e.g. for RSS Feed
    metadata
  end


  # everything else is
  private

  ###########################
  # Helpers

  def check_interface param_name, obj, method_name
    return if obj.respond_to? method_name

    msg = "#{self.class.name}: #{param_name} must respond to `#{method_name}`."

    if obj.class == Class  &&  obj.instance_methods.include?(method_name)
      msg +=
      "\n#{param_name} is a class with an instance method called `#{method_name}`." \
      "\nDid you mean to pass an instance instead?"
    end

    raise msg
  end

  def without_trailing_slash path
    path[%r(.*[^/])]
  end

  def load_file_without_frontmatter filename
    lines = File.read(filename).lines
    if lines.first == "---\n"
      start = lines[1..-1].find_index("---\n") + 2
      lines[start..-1].join
    else
      lines.join
    end
  end

  def get_template filename, all_meta
    @templates ||= {}
    @templates[filename] ||= @template_processor.process_template(
      load_file_without_frontmatter( filename ), all_meta
    )
  end

  # Determine the name for a generated html file.
  # All web pages are saved as "index.html". This creates clean URLs without
  # any need for server-side settings.
  def get_content_output_filename output_dir, filename

    file_basename = File.basename(filename, '.*')

    if file_basename != 'index'
      output_dir = File.join(output_dir, file_basename)
      Dir.mkdir( output_dir )
    end

    File.join(output_dir, 'index.html')
  end


  ###########################
  # Site generation functions

  def backup_output_directory(output_dir)

    if Dir.exist?(output_dir)
      if !Dir.empty?(output_dir)
        File.rename(
          output_dir,
          "#{without_trailing_slash(output_dir)}_#{Time.now.to_i}"
        )
      end
    else
      Dir.mkdir(output_dir)
    end
  end

  def read_input_directory(input_dir)

      $stdout.puts "scanning input directory #{input_dir} ..."

      # Using Pathname::children rather than Dir::children for greater
      # backwards compatibility.
      files = Pathname.new(input_dir).children
      if files  == []
          $stderr.puts "No files in #{input_dir}"
          return
      end

      dir_meta = {
        filename: File.basename(input_dir),
        config: {}, assets: [], content_files: [], content_directories: []
      }

      files.each do |file|
        filename = file.basename.to_s

        if file.directory?

          if filename.end_with?(".content")
            dir_meta[:content_directories].push(
              read_input_directory( File.join(input_dir,filename) )
            )
          else
            dir_meta[:assets].push filename
          end

        else # file is a normal file

          if @content_processor.content_file? filename
            dir_meta[:content_files].push( YAML.load_file(file).merge({filename:filename}) )
          elsif filename.end_with? ".yml"
            dir_meta[:config] = YAML.load_file(file).merge(dir_meta[:config])
          else
            dir_meta[:assets].push filename
          end

        end
      end

      # Fill in the "blanks" in content file metadata with the aggregated
      # directory metadata (config).
      dir_meta[:content_files].each do | file_meta |
        file_meta.merge! dir_meta[:config]
      end

      dir_meta
  end

  def create_tree_and_copy_assets(dir_meta, input_dir, output_dir)

    Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

    dir_meta[:assets].each do |filename|
      FileUtils.cp_r( File.join( input_dir, filename ), output_dir)
    end

    dir_meta[:content_directories].each do |subdir_meta|
      create_tree_and_copy_assets(
        subdir_meta,
        File.join( input_dir, subdir_meta[:filename] ),
        File.join( output_dir, subdir_meta[:filename] ).chomp('.content')
      )
    end
  end

  def inflate_content( all_meta, dir_meta, input_dir, output_dir, templates_dir )

    # For each content file
    dir_meta[:content_files].each do |file_meta|

      template = get_template(
        File.join(templates_dir, file_meta[:template]), all_meta )

      html = @content_processor.process_content(
        load_file_without_frontmatter( File.join( input_dir, file_meta[:filename] ) ),
        template,
        file_meta
      )

      next if ! html

      output_filename =
        get_content_output_filename( output_dir, file_meta[:filename] )

      File.write( output_filename, html )
    end

    # For each content sub-directory
    dir_meta[:content_directories].each do |subdir_meta|
      inflate_content(
        all_meta,
        subdir_meta,
        File.join( input_dir, subdir_meta[:filename] ),
        File.join( output_dir, subdir_meta[:filename].chomp('.content') ),
        templates_dir,
      )
    end
  end
end

# Absolutely *not* the correct place to put this...
def english_ordinal n
  str = n.to_s
  str +
  case str
  when /11$/, /12$/, /13$/
    'th'
  when /1$/
    'st'
  when /2$/
    'nd'
  when /3$/
    'rd'
  else
    'th'
  end
end
