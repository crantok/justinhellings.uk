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
#       - if .content directory
#         - recurse into content directory
#       - else
#         - copy file to output dir

require 'fileutils'
require 'yaml'
require 'mustache'
require 'redcarpet'


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
                $stdout.puts line.inspect
                yaml.push line
            end
        elsif line.start_with? '---'
            has_started_frontmatter = true
        end
    end

    if !has_started_frontmatter
        $stderr.puts "ERROR: Couldn't find frontmatter!"
        exit
    elsif !has_started_content
        $stderr.puts "ERROR: Couldn't find content!"
        exit
    end

    file =
        if yaml.empty?
            {}
        else
            YAML.load(yaml.join)
        end

    # TO DO - Don't instantiate objects for every file, duh!
    file[:content] = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(content.join)
    file
end

# Load an input file, inject its content into a template, save it as an html file
def inflate_webpage(input_file_path, output_directory)

    context = load_file(input_file_path)

    basename = File.basename(input_file_path, '.md')
    if basename == 'index'
        context['is-home-page'] = true
    end

    # mustache renders the file using the template set in config (above)
    file_contents = Mustache.render(context)
    $stdout.puts "length of rendered file: #{file_contents.length}"

    # save file to output/index.html or output/filename/index.html
    output_file_path =
        if basename == 'index'
            output_directory + '/index.html'
        else
            FileUtils.mkdir( output_directory + '/' + basename )
            output_directory + '/' + basename + '/index.html'
        end

    File.write(output_file_path, file_contents)

end

# For the given input_directory, process its content and copy the results to the
# given output_directory.
def build_directory(input_directory, output_directory)

    $stdout.puts "checking output directory ..."
    if ! File.exist?(output_directory)
        FileUtils.mkdir(output_directory)
    end
    if File.file?(output_directory)
        $stdout.puts "#{output_directory} is a regular file. Cannot make output directory of same name."
        exit
    elsif ! Dir[output_directory+'/*'].empty?
        $stdout.puts "#{output_directory} is not empty. Cannot start build."
        exit
    end

    $stdout.puts "scanning input directory ..."

    files = Dir[input_directory+"/*"]
    if files  == []
        $stdout.puts "No files in #{input_directory}"
        return
    end

    $stdout.puts "processing input files ..."

    files.each do |x|
        if File.extname(x) == ".md"
            # inflate relevant template with file content
            $stdout.puts "#{x} is a content file. Inflating and copying to output dir..."
            inflate_webpage(x, output_directory)
        elsif File.extname(x) == ".content" && File.directory?(x)
            $stdout.puts "#{x} is a content directory. Building new output dir..."
            build_directory(x, "#{output_directory}/#{File.basename(x,'.content')}")
        else
            # copy file to output directory
            $stdout.puts "#{x} is an asset. Copying to output dir..."
            FileUtils.cp_r(x, output_directory)
        end
    end

end


####################
# Constants + config

INPUT_DIR = Dir.pwd + "/input"
OUTPUT_DIR = Dir.pwd + "/output"
TEMPLATE = Dir.pwd + '/template.mustache'

Mustache.template_file = TEMPLATE


##################
# main script

build_directory(INPUT_DIR, OUTPUT_DIR)
