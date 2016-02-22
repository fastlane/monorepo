# From http://scottwb.com/blog/2012/07/14/merge-git-repositories-and-preseve-commit-history/

require 'tmpdir'
require 'colored'
require 'pry'

def cmd(command)
  puts "$ #{command}".yellow
  puts `#{command}`
end

require './tools'
names = @tools

url = "https://github.com/fastlane/playground" # the repo everything goes to # TODO: should be fastlane/fastlane

path = Dir.mktmpdir
path = "all_cloned"
destination = "workspace"
FileUtils.rm_rf(path)
FileUtils.rm_rf(destination)
FileUtils.mkdir_p(path)
FileUtils.mkdir_p(destination)

puts `cd '#{destination}' && git clone '#{url}'`
parent_name = url.split("/").last
destination = File.join(destination, parent_name)

# Move the main tool into its subfolder
subfolder_name = ENV["SUBFOLDER_NAME"] || "fastlane"
tmp = Dir.mktmpdir
FileUtils.mv(Dir[File.join(destination, "*")], tmp) # move everything away to create a new fastlane folder
FileUtils.mkdir_p(File.join(destination, subfolder_name))
FileUtils.mv(Dir[File.join(tmp, "*")], File.join(destination, subfolder_name))


names.each do |name|
  cmd "cd '#{path}' && git clone 'https://github.com/fastlane/#{name}' && cd #{name} && git remote rm origin"
end

names.each do |name|
  puts "Rewriting history of '#{name}'"

  ref = File.expand_path("#{path}/#{name}")
  puts "Going to '#{ref}'".green
  Dir.chdir(ref) do
    cmd "mkdir #{name}"
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

Dir.chdir(destination) do
  Dir.foreach(".") do |current|
    next if current == '.' or current == '..'
    next if current == ".git"

    if current.start_with?(".")
      puts "Deleting '#{current}' in the root"
      FileUtils.rm_rf(current)
    end
  end
  cmd "git add -A && git commit -m 'Removed temporary files'"
end

puts `open '#{path}'`
puts `open '#{destination}'`

puts "To push the changes run this:"
puts "cd '#{destination}' && git push".green
