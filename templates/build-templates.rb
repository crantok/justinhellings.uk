#!/usr/bin/env ruby
#
# Build the site templates

require 'mustache'

tpl = File.read 'template.mustache'

File.write('page.template.html', Mustache.render(tpl, {}))
File.write('home.template.html', Mustache.render(tpl, {'is-home-page'=>true}))
File.write('blog.template.html', Mustache.render(tpl, {'is-blog-post'=>true}))
