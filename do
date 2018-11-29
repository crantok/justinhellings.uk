#!/usr/bin/env ruby

require 'pathname'
require 'tmpdir'
require 'yaml'
require 'pp'

require './ssg_extensions'


###########################
# Helpers

def without_trailing_slash path
  path[%r(.*[^/])]
end

def load_file_without_frontmatter filename
  lines = File.read(filename).lines
  if lines.first == "---\n"
    start = lines[1..-1].find_index("---\n") + 1
    lines[start..-1].join
  else
    lines.join
  end
end

def get_template filename, all_metadata
  @templates ||= {}
  @templates[filename] ||= TEMPLATE_PROCESSOR.process(
    load_file_without_frontmatter( filename ), all_metadata )
  @templates[filename].clone
end

# Determine the name for a generated html file.
# All files are saved as "index.html". This creates clean URLs without any need
# for server-side settings.
def get_content_output_filename output_dir, filename

  file_basename = File.basename(filename, '.*')

  if file_basename != 'index'
    output_dir = File.join(output_dir, file_basename)
    Dir.mkdir( output_dir )
  end

  File.join(output_dir, 'index.html')
end

def content_file? path
  CONTENT_SUFFIXES.include?( File.extname(path) )
end


###########################
# Site generation functions

def backup_output_directory(output_directory)

  if Dir.exist?(output_directory)
    if !Dir.empty?(output_directory)
      File.rename(
        output_directory,
        "#{without_trailing_slash(output_directory)}_#{Time.now.to_i}"
      )
    end
  else
    Dir.mkdir(output_directory)
  end
end

def read_input_directory(input_directory)

    $stdout.puts "scanning input directory #{input_directory} ..."

    files = Pathname.new(input_directory).children
    if files  == []
        $stderr.puts "No files in #{input_directory}"
        return
    end

    data = {
      filename: File.basename(input_directory),
      config: {}, assets: [], content_files: [], content_directories: []
    }

    files.each do |file|
      filename = file.basename.to_s

      if file.directory?

        if filename.end_with?(".content")
          data[:content_directories].push(
            read_input_directory( File.join(input_directory,filename) )
          )
        else
          data[:assets].push filename
        end

      else # file is a normal file

        if content_file? filename
          data[:content_files].push( YAML.load_file(file).merge({filename:filename}) )
        elsif filename.end_with? ".yml"
          data[:config] = YAML.load_file(file).merge(data[:config])
        else
          data[:assets].push filename
        end

      end
    end

    data
end

def create_tree_and_copy_assets(data, input_dir, output_dir)

  Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

  data[:assets].each do |filename|
    FileUtils.cp_r( File.join( input_dir, filename ), output_dir)
  end

  data[:content_directories].each do |dir|
    create_tree_and_copy_assets(
      dir,
      File.join( input_dir, dir[:filename] ),
      File.join( output_dir, dir[:filename] ).chomp('.content')
    )
  end
end

def inflate_content( all_data, dir_data, input_dir, output_dir, templates_dir )

  # For each content file
  dir_data[:content_files].each do |file_metadata|

    # fill in any holes in the file data from defaults in the directory config
    file_metadata = dir_data[:config].merge(file_metadata)

    template = get_template(
      File.join(templates_dir, file_metadata[:template]), all_data )

    html = CONTENT_PROCESSOR.process(
      load_file_without_frontmatter( File.join( input_dir, file_metadata[:filename] ) ),
      template,
      file_metadata
    )

    output_filename =
      get_content_output_filename( output_dir, file_metadata[:filename] )

    File.write( output_filename, html )
  end

  # For each content sub-directory
  dir_data[:content_directories].each do |dir|
    inflate_content(
      all_data,
      dir,
      File.join( input_dir, dir[:filename] ),
      File.join( output_dir, dir[:filename].chomp('.content') ),
      templates_dir,
    )
  end
end


####################
# Constants + config

PATHS = {
  input: Dir.pwd + "/input",
  templates: Dir.pwd + "/templates",
  output: Dir.pwd + "/output"
}.freeze


##################
# main script

backup_output_directory(PATHS[:output])

metadata = read_input_directory(PATHS[:input])

create_tree_and_copy_assets(metadata, PATHS[:input], PATHS[:output])

inflate_content(metadata, metadata, PATHS[:input], PATHS[:output], PATHS[:templates])
