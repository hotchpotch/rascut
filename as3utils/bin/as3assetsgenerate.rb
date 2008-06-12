#!/usr/bin/env ruby

require 'pathname'
require 'rubygems'
require 'active_support'
require 'erb'

ignore_ext = %w(css txt)

assets_dir = Pathname.new 'assets'
current = Pathname.new '.'

files = {}
ARGV.each do |f| 
  f = Pathname.new f 
  next unless f.file?
  relative_path = f.relative_path_from(current)
  next if ignore_ext.member? relative_path.extname.sub('.', '')
  var_name = f.relative_path_from(assets_dir).to_s.gsub(/[\/\.]/, '_').camelcase(:lower)
  files[relative_path] = var_name
end

ERB.new(DATA, nil, '%-').run
__END__
package {
    public class Assets {
<% files.each do |path, var_name| -%>
        [Embed(source="<%= path %>")]
        public static var <%= var_name %>:Class;

<% end -%>
    }
}
