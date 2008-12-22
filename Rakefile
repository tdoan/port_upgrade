%w[rubygems rake rake/clean fileutils newgem rubigen].each { |f| require f }
require File.dirname(__FILE__) + '/lib/port_upgrade.rb'

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.new('port_upgrade','0.0.1') do |p|
  p.developer('Tony Doan', 'tdoan@tdoan.com')
  p.changes              = p.paragraphs_of("History.txt", 0..1).join("\n\n")
  p.post_install_message = File.read('PostInstall.txt') # TODO remove if post-install message not required
  p.rubyforge_name       = "portupgrade" # TODO this is default value
  p.summary = "Summary"
  p.extra_deps         = [
    ['sqlite3-ruby','>= 1.2.0'],
    ['libbz2','>= 0.4'],
    ['optiflag','>= 0.6.0'],
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

# TODO - want other tests/tasks run by default? Add them to the list
# task :default => [:spec, :features]
