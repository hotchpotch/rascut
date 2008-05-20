(in /home/gorou/git/rascut)
Gem::Specification.new do |s|
  s.name = %q{rascut}
  s.version = "0.2.0"

  s.specification_version = 2 if s.respond_to? :specification_version=

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Yuichi Tateno"]
  s.autorequire = %q{}
  s.date = %q{2008-05-20}
  s.default_executable = %q{rascut}
  s.description = %q{Ruby ActionSCript UTility}
  s.email = %q{hotchpotch@nospam@gmail.com}
  s.executables = ["rascut"]
  s.extra_rdoc_files = ["README", "ChangeLog"]
  s.files = ["README", "ChangeLog", "Rakefile", "bin/rascut", "bin/rasdoc", "test/test_rascut.rb", "test/test_file_observer.rb", "lib/rascut.rb", "lib/rascut", "lib/rascut/file_observer.rb", "lib/rascut/asdoc", "lib/rascut/asdoc/data.rb", "lib/rascut/asdoc/parser.rb", "lib/rascut/asdoc/httpd.rb", "lib/rascut/asdoc/generator.rb", "lib/rascut/config.rb", "lib/rascut/httpd.rb", "lib/rascut/logger.rb", "lib/rascut/plugin", "lib/rascut/plugin/write_fcsh_error_output.rb", "lib/rascut/plugin/base.rb", "lib/rascut/plugin/screen.rb", "lib/rascut/plugin/generate_ctags.rb", "lib/rascut/command.rb", "lib/rascut/fcsh_wrapper.rb", "lib/rascut/utils.rb", "vendor/js", "vendor/ruby", "vendor/js/swfobject.js", "vendor/ruby/expect.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://hotchpotch.rubyforge.org/rascut/}
  s.rdoc_options = ["--title", "rascut documentation", "--charset", "utf-8", "--opname", "index.html", "--line-numbers", "--main", "README", "--inline-source", "--exclude", "^(examples|extras)/"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.2")
  s.rubyforge_project = %q{hotchpotch}
  s.rubygems_version = %q{1.1.1}
  s.summary = %q{Ruby ActionSCript UTility}
  s.test_files = ["test/test_rascut.rb", "test/test_file_observer.rb"]

  s.add_dependency(%q<rake>, [">= 0"])
  s.add_dependency(%q<mongrel>, [">= 0"])
  s.add_dependency(%q<json_pure>, [">= 0"])
end
