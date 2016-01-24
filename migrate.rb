# From http://scottwb.com/blog/2012/07/14/merge-git-repositories-and-preseve-commit-history/

require 'tmpdir'
require 'colored'

url = "https://github.com/fastlane/final-playground"

names = %w(fastlane fastlane_core deliver snapshot frameit pem sigh produce cert gym pilot credentials_manager scan supply watchbuild match spaceship)

path = Dir.mktmpdir

destination = Dir.mktmpdir
puts `cd '#{destination}' && git clone '#{url}'`
destination = File.join(destination, url.split("/").last)

def cmd(command)
  puts "$ #{command}".yellow
  puts `#{command}`
end

names.each do |name|
  cmd "cd '#{path}' && git clone 'https://github.com/fastlane/#{name}' && git remote rm origin"
end


names.each do |name|
  puts "Rewriting history of '#{name}'"

  ref = "#{path}/#{name}"
  puts "Going to '#{ref}'".green
  Dir.chdir(ref) do
    cmd "mkdir #{name} (to prepare stuff)"
    Dir.foreach(".") do |current| # foreach instead of glob to have hidden items too
      next if current == '.' or current == '..'
      next if current.include?(".git")
      cmd "git mv '#{current}' '#{name}/'"
    end
    cmd "git add -A"
    cmd "git commit -m 'Migrate #{name} to fastlane mono repo'"
  end

  puts "Going to '#{destination}' (to merge stuff)".green
  Dir.chdir(destination) do
    cmd "git remote add local_ref '#{ref}'"
    cmd "git pull local_ref master"
    cmd "git remote rm local_ref"
    cmd "git add -A"
    cmd "git commit -m 'Migrate #{name} to fastlane mono repo'"
  end
end

puts `open '#{path}'`
puts `open '#{destination}'`
