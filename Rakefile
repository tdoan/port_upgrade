require 'hoe'
%w[rubygems rake rake/clean fileutils newgem rubigen].each { |f| require f }
require File.dirname(__FILE__) + '/lib/port_upgrade.rb'
GEM_HOME = File.join(RbConfig::CONFIG["libdir"],RbConfig::CONFIG["RUBY_INSTALL_NAME"],"gems")
GEM_DIR = File.join(GEM_HOME,RbConfig::CONFIG["ruby_version"],"gems")

$hoe = Hoe.new('port_upgrade',Ports::VERSION) do |p|
  p.developer('Tony Doan', 'tdoan@tdoan.com')
  p.changes              = p.paragraphs_of("History.txt", 0..1).join("\n\n")
  p.summary = "Cleanly upgrade your MacPorts."
  p.rubyforge_name       = "portupgrade"
  p.extra_deps         = [
    ['sqlite3-ruby','>= 1.2.0'],
    ['bz2','>= 0.2']
  ]
  p.extra_dev_deps = [
    ['newgem', ">= #{::Newgem::VERSION}"]
  ]
  
  p.clean_globs |= %w[**/.DS_Store tmp *.log]
  path = (p.rubyforge_name == p.name) ? p.rubyforge_name : "\#{p.rubyforge_name}/\#{p.name}"
  p.remote_rdoc_dir = File.join(path.gsub(/^#{p.rubyforge_name}\/?/,''), 'rdoc')
  p.rsync_args = '-av --delete --ignore-errors'
end

require 'newgem/tasks' # load /tasks/*.rake
Dir['tasks/**/*.rake'].each { |t| load t }
