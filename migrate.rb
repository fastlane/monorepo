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
  cmd "cd '#{path}' && git clone 'https://github.com/fastlane/#{name}' && git remote rm origin"
end


cache_path = "/tmp/modified_list.txt"

list_git_index = %q{git filter-branch --index-filter}
create_new_index_and_move = %q{GIT_INDEX_FILE=$GIT_INDEX_FILE.new git update-index --index-info && mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE"}

names.each do |name|
  puts "Rewriting history of '#{name}'"

  ref = File.expand_path("#{path}/#{name}")
  puts "Going to '#{ref}'".green
  Dir.chdir(ref) do
    prefix_with_new_folder = "git ls-files -s | awk '{print $1 \" \" $2 \" \" $3 \"\t\" \"#{name}/\"$4 }'"

    cmd "#{prefix_with_new_folder} > #{cache_path}"
    cmd "#{list_git_index} 'cat #{cache_path} | #{create_new_index_and_move}' --tag-name-filter cat -f -- --all"
  end

  puts "Going to '#{destination}' (to merge stuff)".green
  Dir.chdir(destination) do
    binding.pry

    src_repo = name
    cmd "git remote add -f #{src_repo} '#{ref}'"

    cmd "git pull #{src_repo} master"
    # cmd "git commit -A -m 'manual merge'"

    # cmd "git merge -m \"Merge to the combined repository.\" #{src_repo}/master"
    cmd "git remote rm #{name}"
  end

  #   cmd "mkdir #{name}"
  #   Dir.foreach(".") do |current| # foreach instead of glob to have hidden items too
  #     next if current == '.' or current == '..'
  #     next if current.include?(".git")
  #     cmd "git mv '#{current}' '#{name}/'"
  #   end
  #   cmd "git add -A"
  #   cmd "git commit -m 'Migrate #{name} to fastlane mono repo'"
  # end

  # puts "Going to '#{destination}' (to merge stuff)".green
  # Dir.chdir(destination) do
  #   cmd "git remote add local_ref '#{ref}'"
  #   cmd "git pull local_ref master"
  #   cmd "git remote rm local_ref"
  #   cmd "git add -A"
  #   cmd "git commit -m 'Migrate #{name} to fastlane mono repo'"
  # end
end


binding.pry
raise 'stop'

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
