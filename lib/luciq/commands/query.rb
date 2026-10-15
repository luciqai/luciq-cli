# frozen_string_literal: true

require 'json'
require 'luciq/api/client'
require 'luciq/config'
require 'luciq/commands/query_arguments'

module Luciq
  module Commands
    # Read/query commands. Each public method maps one-to-one to an MCP tool:
    # it builds that tool's arguments from typed CLI flags (see QueryArguments)
    # and proxies to the MCP server's CLI endpoint.
    class Query
      include QueryArguments

      def initialize(options = {})
        @options = options
        @client = API::Client.new
      end

      # --- Crashes -----------------------------------------------------------
      def crashes_list
        execute('list_crashes') { base_args.merge(page_args, sort_args, filters_arg(crash_filters)) }
      end

      def crash_show(number)
        execute('crash_details') { base_args.merge(number: number) }
      end

      def crash_patterns(number)
        pattern = { pattern_key: @options[:pattern_key], sort_by: @options[:sort_by],
                    direction: @options[:direction] }.compact
        execute('crash_patterns') do
          base_args.merge(number: number).merge(pattern).merge(filters_arg(raw_filters))
        end
      end

      def crash_diagnostics(number)
        execute('crash_diagnostics') { base_args.merge(number: number) }
      end

      def occurrence_tokens(number)
        cursor = { current_token: @options[:current_token], direction: @options[:direction] }.compact
        execute('list_occurrences_tokens') do
          base_args.merge(number: number).merge(cursor).merge(filters_arg(raw_filters))
        end
      end

      def occurrence_details(number, ulid)
        execute('get_occurrence_details') { base_args.merge(number: number, ulid: ulid) }
      end

      # --- Bugs --------------------------------------------------------------
      def bugs_list
        execute('list_bugs') { base_args.merge(page_args, sort_args, filters_arg(bug_filters)) }
      end

      def bug_show(number)
        execute('bug_details') { base_args.merge(number: number) }
      end

      def bug_update(number)
        execute('update_bug') { base_args.merge(number: number).merge(bug_update_changes) }
      end

      # --- APM ---------------------------------------------------------------
      def apm_groups
        execute('apm_list_groups') do
          base_args.merge({ metric: @options[:metric] }.compact, page_args)
                   .merge(apm_sort_arg, filters_arg(raw_filters))
        end
      end

      def apm_group
        group = { metric: @options[:metric], group_uuid: @options[:group_uuid],
                  group_url: @options[:group_url], method: @options[:method] }.compact
        views = @options[:views] ? json_arg(:views, @options[:views]) : { views: ['summary'] }
        execute('apm_group_view') do
          base_args.merge(group).merge(views, filters_arg(raw_filters))
        end
      end

      def apm_occurrence
        selector = { metric: @options[:metric], selector: @options[:selector],
                     group_uuid: @options[:group_uuid], group_url: @options[:group_url],
                     method: @options[:method], token: @options[:token],
                     current_token: @options[:current_token],
                     direction: @options[:direction], limit: @options[:limit] }.compact
        execute('apm_occurrence') { base_args.merge(selector).merge(filters_arg(raw_filters)) }
      end

      def apm_funnel_events
        params = { event_type: @options[:event_type], q: @options[:q], limit: @options[:limit] }.compact
        execute('apm_funnel_events') { base_args.merge(params) }
      end

      def apm_funnel_create
        execute('apm_funnel_write') do
          base_args.merge(operation: 'create', name: @options[:name]).merge(json_arg(:events, @options[:events]))
        end
      end

      def apm_funnel_update
        changes = { ulid: @options[:ulid], name: @options[:name] }.compact
        execute('apm_funnel_write') do
          base_args.merge(operation: 'update').merge(changes, json_arg(:events, @options[:events]))
        end
      end

      def apm_funnel_delete
        execute('apm_funnel_write') { base_args.merge(operation: 'delete', ulid: @options[:ulid]) }
      end

      # --- Reviews -----------------------------------------------------------
      def reviews_list
        execute('list_reviews') do
          base_args.merge(page_args, sort_dir_args).merge(filters_arg(review_filters))
        end
      end

      # --- Surveys -----------------------------------------------------------
      def surveys_list
        execute('list_surveys') { base_args.merge(page_args, filters_arg(survey_filters)) }
      end

      def survey_show(id)
        page = { page: @options[:page] }.compact
        execute('survey_details') { base_args.merge(id: id).merge(page, filters_arg(raw_filters)) }
      end

      # --- Applications & health --------------------------------------------
      def apps_list
        execute('list_applications') { page_args.merge({ platform: @options[:platform] }.compact) }
      end

      def insights
        execute('app_insights') { base_args.merge(filters_arg(raw_filters)) }
      end

      # --- Issues ------------------------------------------------------------
      def issues_list
        top = { top_issues: @options[:top_issues] }.compact
        execute('list_issues') do
          base_args.merge({ limit: @options[:limit] }.compact, sort_dir_args, top)
                   .merge(json_arg(:pagination, @options[:pagination]), filters_arg(raw_filters))
        end
      end

      # --- Opportunities -----------------------------------------------------
      def opportunities_list
        execute('list_opportunities') { base_args.merge(page_args, filters_arg(opportunity_filters)) }
      end

      def opportunity_show(id)
        execute('opportunity_details') { base_args.merge(id: id) }
      end

      # --- Alerts (rules) ----------------------------------------------------
      def alerts_list
        execute('read_alerts') { base_args.merge(action: 'list').merge(sort_dir_args) }
      end

      def alert_show(ulid)
        execute('read_alerts') { base_args.merge(action: 'details', ulid: ulid) }
      end

      def alerts_init
        execute('read_alerts') { base_args.merge(action: 'init') }
      end

      def alert_create
        execute('write_alerts') { alert_payload.merge(base_args).merge(action: 'create') }
      end

      def alert_update(ulid)
        execute('write_alerts') { alert_payload.merge(base_args).merge(action: 'update', ulid: ulid) }
      end

      def alert_delete(ulid)
        execute('write_alerts') { base_args.merge(action: 'delete', ulid: ulid) }
      end

      # --- Incidents (triggered alerts) --------------------------------------
      def incidents_list
        execute('read_incidents') do
          base_args.merge(action: 'list').merge(page_args, sort_dir_args, filters_arg(incident_filters))
        end
      end

      def incident_show(ulid)
        execute('read_incidents') { base_args.merge(action: 'details', ulid: ulid) }
      end

      def incident_resolve(ulid)
        execute('write_incidents') { base_args.merge(action: 'resolve', ulid: ulid) }
      end

      def incident_reopen(ulid)
        execute('write_incidents') { base_args.merge(action: 'reopen', ulid: ulid) }
      end

      private

      def execute(tool_name)
        ensure_authenticated!
        print_result(@client.invoke_tool(tool_name, yield))
      rescue StandardError => e
        puts "✗ #{e.message}"
        exit 1
      end

      def ensure_authenticated!
        return if Config.load_token

        puts '✗ Not authenticated. Run: luciq login'
        exit 1
      end

      def print_result(response)
        puts(response.is_a?(String) ? response : JSON.pretty_generate(response))
      end
    end
  end
end
