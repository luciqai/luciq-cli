# frozen_string_literal: true

require 'json'

module Luciq
  module Commands
    # Translates CLI flags (@options) into the argument/filter hashes the MCP
    # tools expect. Mixed into Commands::Query; kept separate so the command
    # dispatch stays thin and the flag→argument mapping is easy to test.
    module QueryArguments
      CRASH_STATUS_IDS = { 'open' => 1, 'closed' => 2, 'in_progress' => 3 }.freeze
      BUG_STATUS_IDS   = { 'new' => 1, 'closed' => 2, 'in_progress' => 3 }.freeze
      BUG_PRIORITY_IDS = { 'na' => -1, 'trivial' => 1, 'minor' => 2, 'major' => 3, 'blocker' => 4 }.freeze
      # Flag pairs `bugs update` refuses together.
      BUG_UPDATE_FLAG_CONFLICTS = [
        [:assignee, :unassign, '--assignee cannot be combined with --unassign'],
        [:team, :clear_team, '--team cannot be combined with --clear-team'],
        [:clear_tags, :tag_action,
         '--clear-tags cannot be combined with --tag-action (--clear-tags already replaces with an empty set)']
      ].freeze

      private

      def base_args
        { slug: @options[:slug], mode: @options[:mode] }
      end

      def page_args
        { offset: @options[:offset], limit: @options[:limit] }.compact
      end

      def sort_args
        { sort_by: @options[:sort_by], direction: @options[:direction] }.compact
      end

      def sort_dir_args
        { sort_by: @options[:sort_by], sort_direction: @options[:sort_direction] }.compact
      end

      def apm_sort_arg
        return {} unless @options[:sort]

        { sort: [parse_json(@options[:sort], '--sort')] }
      end

      def crash_filters
        f = raw_filters
        ids = map_ids(CRASH_STATUS_IDS, @options[:status])
        f['status_id'] = ids unless ids.empty?
        f['platform'] = Array(@options[:platform]) if @options[:platform]
        f['type'] = Array(@options[:type]) if @options[:type]
        f['app_versions'] = Array(@options[:app_version]) if @options[:app_version]
        f
      end

      def bug_filters
        f = raw_filters
        ids = map_ids(BUG_STATUS_IDS, @options[:status])
        f['status_id'] = ids unless ids.empty?
        pri = map_ids(BUG_PRIORITY_IDS, @options[:priority])
        f['priority_id'] = pri unless pri.empty?
        f['app_version'] = Array(@options[:app_version]) if @options[:app_version]
        f
      end

      def review_filters
        f = raw_filters
        f['rating'] = Array(@options[:rating]).map(&:to_i) if @options[:rating]
        f['country'] = Array(@options[:country]) if @options[:country]
        f['os'] = Array(@options[:os]) if @options[:os]
        f
      end

      def survey_filters
        f = raw_filters
        f['type'] = Array(@options[:type]).map(&:to_i) if @options[:type]
        f['status'] = Array(@options[:status]).map(&:to_i) if @options[:status]
        f
      end

      def opportunity_filters
        f = raw_filters
        f['status'] = Array(@options[:status]) if @options[:status]
        f['priority'] = Array(@options[:priority]) if @options[:priority]
        f['team_id'] = @options[:team_id] if @options[:team_id]
        f
      end

      def incident_filters
        f = raw_filters
        f['status'] = Array(@options[:status]) if @options[:status]
        f['type'] = Array(@options[:type]) if @options[:type]
        f
      end

      # Top-level (non-filter) changes for `bugs update`.
      def bug_update_changes
        action = bug_duplicate_action
        reject_conflicting_bug_update_flags!(action)

        changes = {
          status_id: map_one(BUG_STATUS_IDS, @options[:status]),
          priority_id: bug_priority_id(@options[:priority]),
          assignee: @options[:assignee],
          team: (@options[:clear_team] ? '' : @options[:team]),
          tags: (@options[:clear_tags] ? [] : @options[:tags]),
          comment: @options[:comment],
          action: action,
          original_bug_number: @options[:duplicate_of]
        }.compact
        # A null assignee unassigns, so it goes in after compact.
        changes[:assignee] = nil if @options[:unassign]

        if changes.empty?
          raise 'Provide at least one change (--status/--priority/--assignee/--unassign/--team/--clear-team/' \
                '--tags/--clear-tags/--comment/--duplicate-of/--action)'
        end

        # tag_action only modifies how --tags is applied; on its own it is not a change
        if @options[:clear_tags]
          changes[:tag_action] = 'replace'
        elsif @options[:tag_action]
          changes[:tag_action] = @options[:tag_action]
        end

        changes
      end

      def bug_duplicate_action
        return @options[:action] if @options[:action]

        'mark_as_duplicate' if @options[:duplicate_of]
      end

      def reject_conflicting_bug_update_flags!(action)
        # A duplicate takes its status, priority and assignee from its master.
        if action && %i[status priority assignee unassign].any? { |flag| @options[flag] }
          raise 'Duplicate marking cannot be combined with --status/--priority/--assignee/--unassign'
        end

        BUG_UPDATE_FLAG_CONFLICTS.each do |first, second, message|
          raise message if @options[first] && @options[second]
        end
      end

      # A name for a system priority, or the number of one the application added.
      def bug_priority_id(value)
        return if value.nil?
        return BUG_PRIORITY_IDS[value] if BUG_PRIORITY_IDS.key?(value)

        Integer(value, 10)
      rescue ArgumentError
        raise "Unknown --priority #{value}. Use na, trivial, minor, major, blocker, or a custom priority number"
      end

      def filters_arg(filters)
        filters.empty? ? {} : { filters: filters }
      end

      def json_arg(key, raw)
        return {} if raw.nil?

        { key => parse_json(raw, "--#{key}") }
      end

      def raw_filters
        return {} unless @options[:filters]

        parsed = parse_json(@options[:filters], '--filters')
        raise '--filters must be a JSON object' unless parsed.is_a?(Hash)

        parsed
      end

      def alert_payload
        return {} unless @options[:payload]

        parsed = parse_json(@options[:payload], '--payload')
        raise '--payload must be a JSON object' unless parsed.is_a?(Hash)

        parsed.transform_keys(&:to_sym)
      end

      def parse_json(str, label)
        JSON.parse(str)
      rescue JSON::ParserError => e
        raise "Invalid #{label} JSON: #{e.message}"
      end

      def map_ids(mapping, values)
        Array(values).filter_map { |v| mapping[v] }
      end

      def map_one(mapping, value)
        value && mapping[value]
      end
    end
  end
end
