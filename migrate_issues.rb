require 'octokit'
require 'pry'

class Hendl
  # e.g. KrauseFx/fastlane
  attr_accessor :source
  attr_accessor :destination

  # Reason on why this was necessary
  attr_accessor :reason

  def initialize(source: nil, destination: nil, reason: nil)
    self.source = source
    self.destination = destination
    self.reason = reason
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
    body << "This issue was copied from [#{source}##{original.number}](#{original.html_url}) "
    body << "From @#{original.user.login} on #{original.created_at.strftime('%F')}"
    body << "----"
    body << original.body

    tool_name_label = source.split("/").last
    options = { labels: original.labels + [tool_name_label] }
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

    if issue.state == 'open'
      # TODO: improve design + wording here
      body = ["Hello @#{authors.join(", @")}"]
      body << "This issue was automatically migrated from [#{source}##{original.number}](#{original.html_url})."
      body << "Please confirm that this issue is still relevant, otherwise it might automatically be closed after a while :warning:"
      body << "Thanks for your helping making fastlane better :rocket:"
      client.add_comment(destination, issue.number, body.join("\n\n"))

      # Now it's the time to close the old issue
      body = ["Hello @#{original.user.login},"]
      body << reason
      body << "This issue was automatically migrated to [#{destination}##{issue.number}](#{issue.html_url})."
      body << "Please open the newly created issue and confirm that this ticket is still relevant, otherwise it will be closed after a while :warning:"
      body << "Thanks for your helping making fastlane better :rocket:"

      client.add_comment(source, original.number, body.join("\n\n"))
      client.close_issue(source, original.number)
    else
      client.close_issue(destination, issue.number) 
    end
  end

  # We want to comment on PRs and tell the user to re-submit it
  # on the new repo, as we can't migrate them automatically
  def hendl_pr(original)
    puts "#{original.number} is a pull request"

    body = ["Hello @#{original.user.login},"]
    body << reason
    body << "Sorry for the troubles, we'd appreciate if you could re-submit your Pull Request with these changes to the new repository"

    client.add_comment(source, original.number, body.join("\n\n"))
    client.close_pull_request(source, original.number)
  end
end

Hendl.new(source: "fastlane/playground", 
     destination: "fastlane/playground2", 
          reason: "`fastlane` is now a mono repo, you can read more about this decision in our [blog post](https://fastlane.tools). All tools are now available in the [fastlane main repo](https://github.com/fastlane/fastlane).")
