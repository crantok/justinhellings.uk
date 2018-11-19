# ssg_extensions.rb
#
# Site-specific code for the static site generator.

require 'redcarpet'
require 'nokogiri'


CONTENT_SUFFIXES = ['.md']


TEMPLATE_PROCESSOR = Class.new do

  PROCESSORS = [
  ]

  def self.parse raw_template
    Nokogiri::HTML.parse raw_template
  end

  def self.process raw_template
    PROCESSORS.reduce( parse(raw_template) ) do | memo, func |
      func.call(memo)
    end
  end
end


CONTENT_PROCESSOR = Class.new do
  def self.parse raw_content
    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(raw_content)
  end
end


CONTENT_PROCESSOR = Class.new do

  PROCESSORS = [
  ]

  def self.process raw_content
    PROCESSORS.reduce( parse(raw_content) ) do | memo, func |
      func.call(memo)
    end
  end
end
