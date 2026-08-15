# Rakefile
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
  t.verbose = true
end

desc "Lancer nestest"
task :nestest do
  ruby "main.rb --test roms/nestest.nes"
end

task default: :test