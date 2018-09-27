################################
# The TEMPLATE_PROCESSORS hash contains processors that will be applied to
# templates, before the templates are used to create the web pages.
#
# Each processor contains a :data_selector and an :injector. Technically these
# could have been a single function but I feel it's clearer this way.
#
TEMPLATE_PROCESSORS = {

  blog_index: {

    data_selector: ->(metadata) {
      metadata[:blog].map { |memo, (filename, file_config)|
        {
          href: '/' + filename,
          name: file_config[:teaser_name],
          summary: file_config[:teaser_summary],
          date: file_config[:date],
          year: file_config[:date].year
        }
      }.sort { |a,b| -(a[:date] <=> b[:date]) }
    },

    injector: ->(data, dom_fragment) {
      raise '!!!!!!!! No blog data found !!!!!!!!!' if data.empty?

      # Remove the repeatable bit of the DOM fragment
      # Isolate the year + post-entry elements
      # year = nil
      # data.each { |post|
      #   if year != post[:year]
      #     insert year element
      #   end
      #   append post element to last year element
      # }
    }
  }
}
