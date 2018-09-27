#!/usr/bin/env ruby

require 'pathname'
require 'yaml'
require 'pp'

def read_input_directory(input_directory)

    $stdout.puts "scanning input directory #{input_directory} ..."

    files = Pathname.new(input_directory).children
    if files  == []
        $stderr.puts "No files in #{input_directory}"
        return
    end

    data = { type: :content_directory }

    files.each do |filename|
      data[filename.basename.to_s] =
        if filename.directory?
          if filename.to_s.end_with?(".content")
            read_input_directory(filename)
          else
            { type: :asset }
          end
        elsif filename.to_s.end_with? ".md"
          YAML.load_file(filename).merge( { type: :content_file } )
        elsif filename.to_s.end_with? "template.html"
          { type: :raw_template_file }
        else
          { type: :asset }
        end
    end

    data
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

# template = process_templates(metadata)
# write_output_directory()
