
require 'fileutils'
require 'pathname'
require 'yaml'


class StaticSiteGenerator

  def initialize template_processor, content_processor
    check_interface :template_processor, template_processor, :process_template
    check_interface :content_processor, content_processor, :content_file?
    check_interface :content_processor, content_processor, :process_content
    @content_processor = content_processor
    @template_processor = template_processor
  end

  def generate input_dir, output_dir, templates_dir
    backup_output_directory(output_dir)
    metadata = read_input_directory(input_dir)
    create_tree_and_copy_assets(metadata, input_dir, output_dir)
    inflate_content(metadata, metadata, input_dir, output_dir, templates_dir)
  end


  # everything else is
  private

  ###########################
  # Helpers

  def check_interface param_name, obj, method_name
    return if obj.respond_to? method_name

    msg = "#{param_name} must respond to `#{method_name}`."

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

      # fill in any holes in the file metadata from defaults in the directory config
      file_meta = dir_meta[:config].merge(file_meta)

      template = get_template(
        File.join(templates_dir, file_meta[:template]), all_meta )

      html = @content_processor.process_content(
        load_file_without_frontmatter( File.join( input_dir, file_meta[:filename] ) ),
        template,
        file_meta
      )

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
