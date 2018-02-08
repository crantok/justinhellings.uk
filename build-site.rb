#!/usr/bin/env ruby
#
# Build the site from templates and content.
#
# Assumptions:
#   - INPUT_DIR/index.md + template -> output/index.html
#   - INPUT_DIR/other.md + template -> output/other/index.html
#   - all other input files are assets to be copied directly to the output directory
#   - all sub-directories in INPUT_DIR are assets to be copied to the output directory
#
# Algorithm:
#   - Scan input directory for all files
#   - For each file
#       - if .md file
#         - inflate template with yaml and content of md file
#         - save inflated file as output/name-of-md-file/index.html
#       - else
#         - copy file to output dir

require 'fileutils'
require 'yaml'
require 'mustache'


####################
# Constants + config

INPUT_DIR = Dir.pwd + "/input"
OUTPUT_DIR = Dir.pwd + "/output"
TEMPLATE = Dir.pwd + '/template.mustache'

Mustache.template_file = TEMPLATE


####################
# Helpers

# Load a file as a hash from yaml frontmatter and main content.
# ASSUMPTION: All files have a frontmatter section.
def load_file(filename)
    
    has_started_frontmatter = false
    has_started_content = false
    yaml = []
    content = []
    
    File.foreach(filename) do |line|
        if has_started_content
            content.push line
        elsif has_started_frontmatter
            if line.start_with? '---'
                has_started_content = true
            elsif ! line.strip.empty?
                puts line.inspect
                yaml.push line
            end
        elsif line.start_with? '---'
            has_started_frontmatter = true
        end
    end

    if !has_started_frontmatter
        puts "ERROR: Couldn't find frontmatter!"
        exit
    elsif !has_started_content
        puts "ERROR: Couldn't find content!"
        exit
    end
    
    file =
        if yaml.empty?
            {}
        else
            YAML.load(yaml.join)
        end
    file[:content] = content.join
    file
end

# Load an input file, inject its content into a template, save it as an html file
def inflate(input_file_path)
    
    context = load_file(input_file_path)

    basename = File.basename(input_file_path, '.md')
    if basename == 'index'
        context['is-home-page'] = true
    end
    
    # ? markdown process context[:content] ?
    
    # mustache renders the file using the template set in config (above)
    file_contents = Mustache.render(context)
    puts "length of rendered file: #{file_contents.length}"
    
    # save file to output/index.html or output/filename/index.html
    output_file_path =
        if basename == 'index'
            OUTPUT_DIR + '/index.html'
        else
            FileUtils.mkdir( OUTPUT_DIR + '/' + basename )
            OUTPUT_DIR + '/' + basename + '/index.html'
        end

    File.write(output_file_path, file_contents)
    
end


##################
# main script

puts "checking output directory ..."
if ! File.exist?(OUTPUT_DIR)
    FileUtils.mkdir(OUTPUT_DIR)
end
if File.file?(OUTPUT_DIR)
    puts "#{OUTPUT_DIR} is a regular file. Cannot make output directory of same name."
    exit
elsif ! Dir[OUTPUT_DIR+'/*'].empty?
    puts "#{OUTPUT_DIR} is not empty. Cannot start build."
    exit
end

puts "scanning input directory ..."
    
files = Dir[INPUT_DIR+"/*"]
if files  == []
    puts "No files in #{INPUT_DIR}"
    exit
end

puts "processing input files ..."

files.each do |x|
    if File.extname(x) == ".md"
        # inflate relevant template with file content
        puts "#{x} is a content file. Inflating and copying to output dir..."
        inflate(x)
    else
        # copy file to output directory
        puts "#{x} is an asset. Copying to output dir..."
        FileUtils.cp_r(x, OUTPUT_DIR)
    end
end
    
