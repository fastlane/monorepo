require 'octokit'
require 'pry'
require 'excon'
require 'colored'
require 'json'


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
    puts "Fetching issues from '#{source}'..."
    client.issues(source, per_page: 1000).each do |original|
      puts 'current'
      hendl(original)
      smart_sleep
      break
    end
  end

  def hendl(original)
    puts "Hendling #{original.number}"
    if original.pull_request.nil?
      hendl_issue(original)
    else
      hendl_pr(original)
    end
  end

  def smart_sleep
    # via https://developer.github.com/guides/best-practices-for-integrators/#dealing-with-abuse-rate-limits
    #   at least one second between requests
    # also https://developer.github.com/v3/#rate-limiting
    #   maximum of 5000 requests an hour => 83 requests per minute
    sleep 1
  end

  # We copy over all the issues, and also mention everyone
  # so that people are automatically subscribed to notifications
  def hendl_issue(original)
    original_comments = client.issue_comments(source, original.number)
    comments = []
    original_comments.each do |original_comment|
      comments << {
        created_at: original_comment.created_at.iso8601,
        body: original_comment.body
      }
    end

    tool_name_label = source.split("/").last
    body = [original.body, "----", "Original issue by @izuzak"]
    data = {
      issue: {
        title: original.title,
        body: body.join("\n\n"),
        created_at: original.created_at.iso8601,
        labels: original.labels + [tool_name_label],
        closed: original.state != "open"
      },
      comments: comments
    }
    data[:issue][:closed_at] = original.closed_at.iso8601 if original.state != "open"

    puts data.to_s.green
    puts ""
    response = Excon.post("https://api.github.com/repos/#{destination}/import/issues", body: data.to_json, headers: request_headers)
    response = JSON.parse(response.body)
    puts response.to_s.yellow

    # TODO: link from old issue here and close the old one
  end

  def request_headers
    {
      "Accept" => "application/vnd.github.golden-comet-preview+json",
      "Authorization" => ("token " + ENV["GITHUB_API_TOKEN"]),
      "Content-Type" => "application/x-www-form-urlencoded",
      "User-Agent" => "fastlane bot"
    }
  end

  # We want to comment on PRs and tell the user to re-submit it
  # on the new repo, as we can't migrate them automatically
  def hendl_pr(original)
    # puts "#{original.number} is a pull request"

    # body = ["Hello @#{original.user.login},"]
    # body << "Sorry for the troubles, we'd appreciate if you could re-submit your Pull Request with these changes to the new repository"

    # client.add_comment(source, original.number, body.join("\n\n"))
    # client.close_pull_request(source, original.number)
    # smart_sleep
  end
end

Hendl.new(source: "fastlane/playground", 
     destination: "fastlane/playground2")
