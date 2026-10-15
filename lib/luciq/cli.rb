# frozen_string_literal: true

require 'thor'
require 'luciq/version'
require 'luciq/commands/auth'
require 'luciq/upload_cli'
require 'luciq/query_cli'

module Luciq
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'login', 'Authenticate with Luciq'
    long_desc <<~DESC
      Authenticate with Luciq using a CLI token.
      Generate a CLI token from your Luciq dashboard: https://dashboard.luciq.ai/company/luciq-cli
      The token will be saved in ~/.luciqrc
    DESC
    option :auth_token, type: :string, desc: 'CLI authentication token'
    def login
      Commands::Auth.new(options).login
    end

    desc 'logout', 'Remove saved authentication'
    def logout
      Commands::Auth.new(options).logout
    end

    desc 'whoami', 'Show current authenticated user'
    def whoami
      Commands::Auth.new(options).whoami
    end

    desc 'info', 'Show CLI configuration'
    def info
      Commands::Auth.new(options).info
    end

    desc 'upload SUBCOMMAND', 'Upload symbol files to Luciq'
    subcommand 'upload', UploadCLI

    desc 'crashes SUBCOMMAND', 'Query crashes (list, show, patterns, diagnostics, occurrence-tokens, occurrence)'
    subcommand 'crashes', CrashesCLI

    desc 'bugs SUBCOMMAND', 'Query bugs (list, show, update)'
    subcommand 'bugs', BugsCLI

    desc 'apm SUBCOMMAND', 'Query APM data (groups, group, occurrence, funnels)'
    subcommand 'apm', ApmCLI

    desc 'reviews SUBCOMMAND', 'Query app reviews (list)'
    subcommand 'reviews', ReviewsCLI

    desc 'surveys SUBCOMMAND', 'Query surveys (list, show)'
    subcommand 'surveys', SurveysCLI

    desc 'apps SUBCOMMAND', 'List accessible applications'
    subcommand 'apps', AppsCLI

    desc 'issues SUBCOMMAND', 'Query issues ranked by impact (list)'
    subcommand 'issues', IssuesCLI

    desc 'opportunities SUBCOMMAND', 'Query opportunities (list, show)'
    subcommand 'opportunities', OpportunitiesCLI

    desc 'alerts SUBCOMMAND', 'Manage alert rules (list, show, init, create, update, delete)'
    subcommand 'alerts', AlertsCLI

    desc 'incidents SUBCOMMAND', 'Manage triggered alerts (list, show, resolve, reopen)'
    subcommand 'incidents', IncidentsCLI

    desc 'insights', 'Show aggregated app-health insights for an application'
    long_desc(<<~DESC, wrap: false)
      Show aggregated app-health insights for an application.

      Filters via --filters:
        date_ms      {"gte": <ms>, "lte": <ms>}
        app_version  ["1.2.3", ...]
    DESC
    QueryOptions.app(self)
    QueryOptions.raw_filters(self)
    def insights
      Commands::Query.new(options).insights
    end

    desc 'version', 'Show CLI version'
    def version
      puts "luciq-cli #{Luciq::VERSION}"
    end

    map %w[--version] => :version
  end
end
