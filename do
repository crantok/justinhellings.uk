#!/usr/bin/env ruby

require 'pathname'
require 'tmpdir'
require 'yaml'
require 'pp'

require './ssg_extensions'

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

def process_template tpl
  TEMPLATE_PROCESSORS.each do |processor|
    tpl = processor(tpl)
  end
  tpl
end

def process_content doc
  CONTENT_PROCESSORS.each do |processor|
    doc = processor(doc)
  end
  doc
end


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

def get_template filename
  @templates ||= {}
  @templates[filename] ||= process_template(
    TEMPLATE_PARSER.parse( load_file_without_frontmatter(filename) )
  )
  @templates[filename].clone
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

        if filename.end_with? CONTENT_SUFFIX
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

  output_dir = output_dir.chomp('.content')

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

def inflate_content( data, input_dir, templates_dir, output_dir )

  output_dir = output_dir.chomp('.content')

  # For each content file
  data[:content_files].each do |file_metadata|

    # fill in any holes in the file data from defaults in the directory config
    file_metadata = data[:config].merge(file_metadata)

    template = get_template(File.join(templates_dir, file_metadata[:template]))

    filename = file_metadata[:filename]

    content = CONTENT_PARSER.parse(
      File.read( File.join( input_dir, filename ) )
    )

    # ?? Where and how to insert content into the template ??
    # ?? Where and how to insert content into the template ??
    # ?? Where and how to insert content into the template ??
    # ?? Where and how to insert content into the template ??

    html = process_content( template_containing_content = ' ' )

    outdir = output_dir
    file_basename = File.basename(filename, CONTENT_SUFFIX)
    if file_basename != 'index'
      outdir = File.join(output_dir, file_basename)
      Dir.mkdir( outdir )
    end
    File.write( File.join(outdir, 'index.html'), html )
  end

  data[:content_directories].each do |dir|
    inflate_content(
      dir,
      File.join( input_dir, dir[:filename] ),
      templates_dir,
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

  inflate_content(metadata, PATHS[:input], PATHS[:templates], target)
  pp Dir.glob("#{target}/**/*/")
end

# pp @templates

# template = process_templates(metadata)
# write_output_directory()
