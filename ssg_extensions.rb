# ssg_extensions.rb
#
# Site-specific code for the static site generator.

require 'redcarpet'
require 'nokogiri'

TEMPLATE_PARSER = Nokogiri::HTML

CONTENT_SUFFIX = '.md'

CONTENT_PARSER = Class.new do
  def self.parse raw_content
    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(raw_content)
  end
end

TEMPLATE_PROCESSORS = []

CONTENT_PROCESSORS = []
