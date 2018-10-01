#!/usr/bin/env ruby

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

def copy_assets(data, input_dir, output_dir)
  puts input_dir, output_dir

  Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

  data[:assets].each do |filename|
    FileUtils.cp_r( File.join( input_dir, filename ), output_dir)
  end

  data[:content_directories].each do |dir|
    copy_assets(
      dir,
      File.join( input_dir, dir[:filename] ),
      File.join( output_dir, dir[:filename] ))
  end
end


####################
# Constants + config

INPUT_DIR = Dir.pwd + "/input"
OUTPUT_DIR = Dir.pwd + "/output"
TEMPLATE = Dir.pwd + '/template.mustache'


##################
# main script

metadata = read_input_directory(INPUT_DIR)
pp metadata

Dir.mktmpdir do |target|
  copy_assets(metadata, INPUT_DIR, target)
  Dir.glob("#{target}/**/*/").each{|x|puts x}
end

# template = process_templates(metadata)
# write_output_directory()
