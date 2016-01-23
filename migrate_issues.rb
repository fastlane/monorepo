require 'octokit'
require 'pry'

class Hendl
  # e.g. KrauseFx/fastlane
  attr_accessor :source
  attr_accessor :destination

  def initialize(source: nil, destination: nil)
    self.source = source
    self.destination = destination
    self.start
  end

  def client
    @client ||= Octokit::Client.new(access_token: ENV["GITHUB_API_TOKEN"])
  end

  def start
    client.issues(source, per_page: 1000).each do |original|
      hendl(original)
    end
  end

  def hendl(original)
    if original.pull_request.nil?
      hendl_issue(original)
    else
      hendl_pr(original)
    end
  end

  # We copy over all the issues, and also mention everyone
  # so that people are automatically subscribed to notifications
  def hendl_issue(original)
    body = []
    body << "This issue is copied from [#{source}##{original.number}](#{original.html_url}) "
    body << "From @#{original.user.login} on #{original.created_at.strftime('%F')}"
    body << "----"
    body << original.body

    options = { labels: original.labels }
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

  # We want to comment on PRs and tell the user to re-submit it
  # on the new repo, as we can't migrate them automatically
  def hendl_pr(original)
    puts "#{original.number} is a pull request"

    body = ["Hello @#{original.user.login},"]
    body << "This repository is now deprecated, since it was merged to [#{destination}](https://github.com/#{destination})"
    body << "Please re-submit the PR with these changes to the new repository"

    client.add_comment(source, original.number, body.join("\n\n"))
    client.close_pull_request(source, original.number)
  end
end

Hendl.new(source: "fastlane/playground", destination: "fastlane/playground2")
