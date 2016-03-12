require 'octokit'
require 'pry'
require 'excon'
require 'colored'
require 'json'
require 'faraday'


class Locker
  # e.g. KrauseFx/fastlane
  attr_accessor :repo

  def initialize(repo: nil)
    self.repo = repo
    self.start
  end

  def client
    @client ||= Octokit::Client.new(access_token: ENV["GITHUB_API_TOKEN"])
  end

  def start
    client.auto_paginate = true
    puts "Fetching issues from '#{repo}'..."
    counter = 0
    client.issues(repo, per_page: 1000, state: "all").each do |original|
      lock_issue(repo_name: repo, issue_id: original.number)
      smart_sleep
      counter += 1
    end
    puts "[SUCCESS] Migrated #{counter} issues / PRs"
  end

  def lock_issue(repo_name: nil, issue_id: nil)
    response = connection.put do |req|
      req.url "repos/#{repo_name}/issues/#{issue_id}/lock"
      req.headers['Authorization'] = "token #{ENV['GITHUB_API_TOKEN']}"
      req.headers['Content-Length'] = 0
      req.headers['Accept'] = "application/vnd.github.the-key-preview"
    end
    remaining = response.env.response_headers["x-ratelimit-remaining"].to_i
    puts "Requests remaining: #{remaining}".yellow if remaining % 10 == 0
    if response.status.to_s == "204"
      puts "Success Locking Issue: #{repo_name}: #{issue_id}".green
    else
      puts "Failed Locking Issue:  #{repo_name}: #{issue_id}".red
      puts "Error: #{response}"
    end
  end

  def connection
    @connection ||= Faraday.new(url: "https://api.github.com/") do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end
  end

  def smart_sleep
    # via https://developer.github.com/guides/best-practices-for-integrators/#dealing-with-abuse-rate-limits
    #   at least one second between requests
    # also https://developer.github.com/v3/#rate-limiting
    #   maximum of 5000 requests an hour => 83 requests per minute
    sleep 2.5
  end
end



require './tools'
destination = "fastlane/fastlane" # TODO: Should be fastlane
names = Array(ENV["TOOL"] || @tools.delete_if { |a| a == "fastlane" }) # we don't want to import issues from our own repo
puts "Locking #{names.join(', ')}"

names.each do |current|
  Locker.new(repo: "fastlane/#{current}")
end
