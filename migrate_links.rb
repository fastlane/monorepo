require 'pry'

new_repo = "fastlane"
new_repo = "playground"
exceptions = ["countdown", "boarding", "fastlane.tools", "refresher", "examples", "setups", "shenzhen", "itc-api-docs", "enhancer", "brewed-jenkins", "codes", "code-of-conduct", "spaceship.airforce"]

Dir["./workspace/**/*"].each do |path|
  next unless File.exist?(path)
  next if File.directory?(path)
  next unless ["rb", "txt", "md"].include?(path.split(".").last)

  puts "Converting #{path}"

  content = File.read(path)
  content.gsub!(/https\:\/\/github.com\/fastlane\/(\w+)/) do |line|
    tool_name = Regexp.last_match[1]
    if exceptions.include?(tool_name)
      "https://github.com/fastlane/#{tool_name}"
    else
      "https://github.com/fastlane/#{new_repo}/tree/master/#{tool_name}"
    end
  end

  File.write(path, content)
end
