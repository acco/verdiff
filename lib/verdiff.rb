require_relative 'verdiff/version'
require 'erb'
require 'diffy'

module Verdiff

  class << self
    DIFF_HEADER_INSERT_OFFSET = '<div class="diff">'.size
    CSS_TEMPLATE_FILE = File.expand_path(File.join(__FILE__, '../', 'templates/diff.css.erb'))
    HTML_TEMPLATE_FILE = File.expand_path(File.join(__FILE__, '../', 'templates/diff.html.erb'))
    def diff_files(file_paths, diff_out_file_path)
      file_paths = [ file_paths ].flatten
      if !File.exists?(diff_out_file_path)
        raise "Error: Invalid path `#{diff_out_file_path}`"
      end

      diffs = []

      (1).upto(file_paths.size-1).each do |n|
        a = file_paths[n-1]
        b = file_paths[n]
        diffs << Diff.new(diff(a,b), File.basename(a), File.basename(b))
      end

      css_namespace = GenericNamespace.new({ css: Diffy::CSS })
      css_template = File.open(CSS_TEMPLATE_FILE).read
      css_out = ERB.new(css_template).result(css_namespace.get_binding)

      css_file_path = File.join(diff_out_file_path, 'diff.css')

      File.open(css_file_path, 'w+') do |f|
        f.write css_out
      end
      log("Wrote #{truncate_left(css_file_path, 50)}")

      html = diffs.inject("") do |memo, element|
        memo += "\n<hr>\n"
        memo += "<h1>#{element.name}<h1>"
        memo += element.html

        memo
      end

      template = File.open(HTML_TEMPLATE_FILE).read
      namespace = GenericNamespace.new({ html: html, title: 'Diffs' })
      diff_file_path = File.join(diff_out_file_path, "diffs.html")
      File.open(diff_file_path, 'w+') do |f|
        f.write ERB.new(template).result(namespace.get_binding)
      end
      log("Wrote #{truncate_left(diff_file_path, 50)}")
      log("CMD+CLICK to view:\n" + diff_file_path)
    end

    private

    def truncate_left(str, chrs)
      if str.size <= chrs
        str
      else
        start = -(chrs + 1)
        '...' + str[start.. -1]
      end
    end

    def diff(a, b)
      Diffy::Diff.new(a, b, :source => 'files').to_s(:html_simple)
    end

    def warn(text)
      l "%s: WARN: %s" % [Time.now, text]
    end

    def error(text)
      l "%s: ERROR: %s" % [Time.now, text]
    end

    def log(text)
      l "%s: %s" % [Time.now, text]
    end

    def l(text)
      unless ENV['TEST']
        STDERR.puts(text)
      end
    end

    class Diff < Struct.new(:html, :file_name_1, :file_name_2)
      def name
        "Between #{file_name_1} & #{file_name_2}"
      end
    end

    class GenericNamespace
      def initialize(hash)
        set(hash)
      end

      def get_binding
        binding
      end

      private

      def set(hash)
        hash.each do |k, v|
          instance_variable_set('@' + k.to_s, v)
        end
      end
    end
  end
end
