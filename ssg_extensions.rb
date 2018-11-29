# ssg_extensions.rb
#
# Site-specific code for the static site generator.

require 'redcarpet'
require 'nokogiri'

###########################
# Experiments

def find_element_by_text doc, text
  doc.at(":contains('#{text}'):not(:has(:contains('#{text}')))")
end

def replace_content doc, placeholder, content
  doc.at("replace:contains('#{placeholder}')").replace(content)
end


###########################
# Extensions interface

CONTENT_SUFFIXES = ['.md']


class TemplateProcessor

  PROCESSORS = [
    # Testing that passing template straight through works
    ->(template, metadata) do
      template
    end,

    ->(template, metadata) do
      if template.at_css(".blog-posts")
        blog_meta = metadata[:content_directories].find {|dir| dir[:filename] == 'blog.content'}
        pp blog_meta

        # blog_meta[:content_files].map { |memo, file_meta|
        #   {
        #     href: '/' + filename,
        #     name: file_meta[:teaser_name],
        #     summary: file_meta[:teaser_summary],
        #     date: file_meta[:date],
        #     year: file_meta[:date].year
        #   }
        # }.sort { |a,b| -(a[:date] <=> b[:date]) }


        #squirt blog posts into sidebar
      end
      template # pass straight through for now
    end
  ]

  def self.parse raw_template
    Nokogiri::HTML.parse raw_template
  end

  def self.process raw_template, all_metadata
    PROCESSORS.reduce( parse(raw_template) ) do | memo, func |
      func.call(memo, all_metadata)
    end
  end
end
TEMPLATE_PROCESSOR = TemplateProcessor


class ContentProcessor

  PROCESSORS = [
    # Testing that passing content straight through works
    ->(content, metadata) do
      content
    end
  ]

  def self.templated_content markdown, template
    main = template.at_css("main")
    main.content = ""
    main.add_child(
      Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(markdown) )
    template
  end

  def self.process markdown, template, metadata
    PROCESSORS.reduce( templated_content(markdown, template) ) do | memo, func |
      func.call(memo, metadata)
    end
  end
end
CONTENT_PROCESSOR = ContentProcessor
