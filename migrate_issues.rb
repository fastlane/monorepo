require 'octokit'
require 'pry'
client = Octokit::Client.new(access_token: ENV["GITHUB_API_TOKEN"])
Octokit.auto_paginate = true

source = "fastlane/sigh"
destination = "fastlane/playground"

client.issues(source, per_page: 1000).each do |original|
  unless original.pull_request.nil?
    puts "#{original.number} is a pull request"
    next
  end

  body = []
  body << "This issue is copied from [#{source}##{original.number}](#{original.html_url}) "
  body << "From @#{original.user.login} on #{original.created_at.strftime('%F')}"
  body << "----"
  body << original.body

  options = {labels: original.labels}
  options[:assignee] = original.assignee.login if original.assignee

  puts "Copying issue #{original.number} from #{source}..."
  issue = client.create_issue(destination, 
                              original.title, 
                              body.join("\n\n"), 
                              options)
  

  authors = [original.user.login]

  original_comments = client.issue_comments(source, original.number)
  original_comments.each do |original_comment|
    body = []
    body << "From @#{original_comment.user.login} on #{original_comment.created_at.strftime('%F')}"
    body << "----"
    body << original_comment.body
    puts "Copying issue comment #{original_comment.id}..."
    client.add_comment(destination, issue.number, body.join("\n\n"))

    authors << original_comment.user.login
  end

  # TODO: improve design + wording here
  body = ["Hello @" + authors.join(", @")]
  body << "This issue was automatically migrated from [#{source}##{original.number}](#{original.html_url})."
  body << "Please confirm that this issue is still relevant, otherwise it might automatically be closed after a while"
  body << "Thanks for your helping making fastlane better :rocket:"
  client.add_comment(destination, issue.number, body.join("\n\n"))

  client.close_issue(destination, issue.number) if issue.state != 'open'
end
