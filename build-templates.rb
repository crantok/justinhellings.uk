#!/usr/bin/env ruby
#
# Build the site templates

require 'mustache'

tpl = File.read './templates/template.mustache'

File.write('./templates/page.template.html', Mustache.render(tpl, {}))
File.write('./templates/home.template.html', Mustache.render(tpl, {'is-home-page'=>true}))
File.write('./templates/blog.template.html', Mustache.render(tpl, {'is-blog-post'=>true}))
