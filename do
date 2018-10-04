#!/usr/bin/env ruby

require 'nokogiri'
require 'pathname'
require 'tmpdir'
require 'yaml'
require 'pp'

def read_input_directory(input_directory)

    $stdout.puts "scanning input directory #{input_directory} ..."

    files = Pathname.new(input_directory).children
    if files  == []
        $stderr.puts "No files in #{input_directory}"
        return
    end

    data = {
      filename: File.basename(input_directory),
      templates: [], assets: [], content_directories: [], content_files: []
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
      elsif file.to_s.end_with? "template.html"
        data[:templates].push filename
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

class ErrTooManyTemplate < StandardError
  def initialise directory, templates
    super "Too many templates in #{directory}\n #{data[:templates].inspect}"
  end
end

class ErrNoTemplateFound < StandardError
  def initialise directory
    super "No templates found in #{directory} and no parent template given"
  end
end

class ErrSkipDirectory < StandardError
end

def inflate_content( data, input_dir, output_dir, parent_template = nil)

  begin

    # Get the template for content in this directory or raise an appropriate
    # error.
    if data[:templates].count > 1
      raise ErrTooManyTemplates, input_dir, data[:templates]
    elsif data[:templates].empty?
      template = parent_template
      if not template
        if data[:content_files].empty?
          raise ErrSkipDirectory
        else
          raise ErrNoTemplateFound, input_dir
        end
      end
    else # exactly one template in this directory
      template = Nokogiri::HTML(File.read(File.join(input_dir, data[:templates].first)))
    end

    # Check template contains 'insert-content-here'
    x = template.at('content-goes-here')
    pp x
    exit
    # pp template.at(':contains("")')

    # If parent_template, insert current template into parent


    # Apply template processors to template

    # For each content file
      # apply content_processors to content
      # save file to target directory

    # recurse_with_new_template
  rescue ErrSkipDirectory
  end

  data[:content_directories].each do |dir|
    inflate_content(
      dir,
      File.join( input_dir, dir[:filename] ),
      File.join( output_dir, dir[:filename] ),
      template)
  end
end

####################
# Constants + config

INPUT_DIR = Dir.pwd + "/input"
OUTPUT_DIR = Dir.pwd + "/output"


##################
# main script

metadata = read_input_directory(INPUT_DIR)
pp metadata

Dir.mktmpdir do |target|
  create_tree_and_copy_assets(metadata, INPUT_DIR, target)
  pp Dir.glob("#{target}/**/*/")

  inflate_content(metadata, INPUT_DIR, target)
  pp Dir.glob("#{target}/**/*/")
end

# template = process_templates(metadata)
# write_output_directory()
