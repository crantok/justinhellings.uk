#!/usr/bin/env ruby

require 'nokogiri'
require 'pathname'
require 'tmpdir'
require 'yaml'
require 'pp'

###########################
# Experiments

def find_element_by_text doc, text
  doc.at(":contains('#{text}'):not(:has(:contains('#{text}')))")
end

def replace_content doc, placeholder, content
  doc.at("replace:contains('#{placeholder}')").replace(content)
end


###########################
# Helpers

def without_trailing_slash path
  path[%r(.*[^/])]
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
      assets: [], content_directories: [], content_files: []
    }

    files.each do |file|

      # ?TODO?
      # if file is normal file and ends with .yml
      #   merge yaml into data
      # else
      #   ...
      # ?TODO?

      filename = file.basename.to_s

      if file.directory?
        if filename.end_with?(".content")
          data[:content_directories].push(
            read_input_directory( File.join(input_directory,filename) )
          )
        else
          data[:assets].push filename
        end
      elsif filename.end_with? ".md"
        data[:content_files].push( YAML.load_file(file).merge({filename:filename}) )
      else
        data[:assets].push filename
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
      File.join( output_dir, dir[:filename] ))
  end
end

def inflate_content( data, input_dir, output_dir )

  # For each content file
  #   get_template( template_name ) # <- performs any necessary template processing, e.g. blog sidebar
  #   markdown -> markup
  #   insert content markup + metadata into template
  #   save file
  # end

  data[:content_directories].each do |dir|
    inflate_content(
      dir,
      File.join( input_dir, dir[:filename] ),
      File.join( output_dir, dir[:filename] ))
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
pp metadata

Dir.mktmpdir do |target|
  create_tree_and_copy_assets(metadata, PATHS[:input], target)
  pp Dir.glob("#{target}/**/*/")

  inflate_content(metadata, PATHS[:input], target)
  pp Dir.glob("#{target}/**/*/")
end

# template = process_templates(metadata)
# write_output_directory()
