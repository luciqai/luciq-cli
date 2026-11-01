# frozen_string_literal: true

require 'luciq/commands/query_arguments'

module Luciq
  module Commands
    # Translates the `bugs update` flags into update_bug arguments. Mixed into
    # Commands::Query next to QueryArguments, whose status and priority names
    # and map_one helper it shares.
    module BugUpdateArguments
      # Flag pairs `bugs update` refuses together.
      BUG_UPDATE_FLAG_CONFLICTS = [
        [:assignee, :unassign, '--assignee cannot be combined with --unassign'],
        [:team, :clear_team, '--team cannot be combined with --clear-team'],
        [:clear_tags, :tag_action,
         '--clear-tags cannot be combined with --tag-action (--clear-tags already replaces with an empty set)']
      ].freeze
      # `bugs update` flags that refuse a blank value. The server reads a blank
      # assignee or team as "unassign", so an empty shell variable would clear
      # the field without a word; --unassign and --clear-team say it explicitly.
      BUG_UPDATE_NON_BLANK_FLAGS = {
        assignee: "--assignee needs a teammate's email. Use --unassign to remove the assignee",
        team: '--team needs a team name or id. Use --clear-team to remove the team',
        comment: '--comment needs text'
      }.freeze

      private

      # Top-level (non-filter) changes for `bugs update`.
      def bug_update_changes
        action = bug_duplicate_action
        validate_bug_update_flags!(action)

        changes = {
          status_id: map_one(QueryArguments::BUG_STATUS_IDS, @options[:status]),
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

      def validate_bug_update_flags!(action)
        reject_blank_bug_update_values!
        reject_conflicting_bug_update_flags!(action)
      end

      def reject_blank_bug_update_values!
        BUG_UPDATE_NON_BLANK_FLAGS.each do |flag, message|
          raise message if @options[flag]&.strip&.empty?
        end
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
        priorities = QueryArguments::BUG_PRIORITY_IDS
        return if value.nil?
        return priorities[value] if priorities.key?(value)

        Integer(value, 10)
      rescue ArgumentError
        raise "Unknown --priority #{value}. Use na, trivial, minor, major, blocker, or a custom priority number"
      end
    end
  end
end
