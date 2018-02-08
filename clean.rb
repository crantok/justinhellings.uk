#!/usr/bin/env ruby
#
# Clean the output directory - remove all files.

require 'fileutils'

OUTPUT_DIR = Dir.pwd + "/output"

FileUtils.rm_r(Dir[OUTPUT_DIR + '/*'])
