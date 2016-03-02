require 'octokit'
require 'pry'
require 'excon'
require 'colored'
require 'json'


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
    client.auto_paginate = true
    puts "Fetching issues from '#{source}'..."
    counter = 0
    client.issues(source, per_page: 1000, state: "all").each do |original|
      labels = original.labels.collect { |a| a[:name] }
      if labels.include?("migrated") or labels.include?("migration_failed")
        puts "Skipping #{original.number} because it's already migrated or failed"
        next
      end

      hendl(original)
      smart_sleep
      counter += 1
    end
    puts "[SUCCESS] Migrated #{counter} issues / PRs"
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

  def table(user_id, body)
    "<table>
      <tr>
        <td>
          <img src='https://avatars0.githubusercontent.com/u/#{user_id}?v=3&s=140' width='70'>
        </td>
        <td>
          #{body}
        </td>
      </tr>
    </table>"
  end

  # We copy over all the issues, and also mention everyone
  # so that people are automatically subscribed to notifications
  def hendl_issue(original)
    original_comments = client.issue_comments(source, original.number)
    comments = []
    original_comments.each do |original_comment|
      table_code = table(original_comment.user.id, "Original comment by @#{original_comment.user.login}")
      body = [table_code, original_comment.body]
      comments << {
        created_at: original_comment.created_at.iso8601,
        body: body.join("\n\n")
      }
    end

    actual_label = original.labels.collect { |a| a[:name] }

    tool_name_label = source.split("/").last
    table_link = "Imported from <a href='#{original.html_url}'>#{source}##{original.number}</a>"
    table_code = table(original.user.id, "Original issue by @#{original.user.login} - #{table_link}")
    body = [table_code, original.body]
    data = {
      issue: {
        title: original.title,
        body: body.join("\n\n"),
        created_at: original.created_at.iso8601,
        labels: actual_label + [tool_name_label],
        closed: original.state != "open"
      },
      comments: comments
    }
    data[:issue][:closed_at] = original.closed_at.iso8601 if original.state != "open"

    response = Excon.post("https://api.github.com/repos/#{destination}/import/issues", body: data.to_json, headers: request_headers)
    response = JSON.parse(response.body)
    status_url = response['url']
    puts response

    new_issue_url = nil

    begin
      (5..35).each do |request_num|
        sleep(request_num)

        puts "Sending #{status_url}"
        async_response = Excon.get(status_url, headers: request_headers) # if this crashes, make sure to have a valid token with admin permission to the actual repo
        async_response = JSON.parse(async_response.body)
        puts async_response.to_s.yellow

        new_issue_url = async_response['issue_url']
        break if new_issue_url.to_s.length > 0
        puts "unable to get new issue url for #{original.number} after #{request_num - 4} requests".yellow
      end
    rescue => ex
      puts "Something went wrong, wups"
      puts ex.to_s
      # If the error message is
      # {"message"=>"Not Found", "documentation_url"=>"https://developer.github.com/v3"}
      # that just means that fastlane-bot doesn't have admin access
    end

    if new_issue_url.to_s.length > 0
      new_issue_url.gsub!("api.github.com/repos", "github.com")

      # reason, link to the new issue
      puts "closing old issue #{original.number}"
      body = [reason]
      body << "Please post all further comments on the [new issue](#{new_issue_url})."
      client.add_comment(source, original.number, body.join("\n\n"))
      smart_sleep
      client.close_issue(source, original.number) unless original.state == "closed"
      client.update_issue(source, original.number, labels: (actual_label + ["migrated"]))
    else
      puts "unable to find new issue url, not closing or commenting".red
      client.update_issue(source, original.number, labels: (actual_label + ["migration_failed"]))
      puts "Status URL: #{status_url}"
      # This means we have to manually migrate the issue
      # if you want to try it again, just remove the migration_failed tag
    end
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
    puts "#{original.number} is a pull request"
    if original.state != "open"
      puts "#{original.number} is already closed - nothing to do here"
      return
    end

    body = ["Hello @#{original.user.login},"]
    body << reason
    body << "Sorry for the troubles, we'd appreciate if you could re-submit your Pull Request with these changes to the new repository"

    client.add_comment(source, original.number, body.join("\n\n"))
    smart_sleep
    client.close_pull_request(source, original.number)
  end
end

require './tools'
names = @tools.reject { |tool| tool == "fastlane" } # we don't want to import issues from our own repo
destination = "fastlane/playground" # TODO: Should be fastlane
names.each do |current|
  Hendl.new(source: "fastlane/#{current}",
       destination: destination,
            reason: "`fastlane` is now a mono repo, you can read more about the change in our [blog post](https://krausefx.com/blog/our-goal-to-unify-fastlane-tools). All tools are now available in the [fastlane main repo](https://github.com/fastlane/fastlane).")
end
