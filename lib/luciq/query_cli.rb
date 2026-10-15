# frozen_string_literal: true

require 'thor'
require 'luciq/commands/query'

module Luciq
  # Shared Thor option groups for query commands.
  module QueryOptions
    MODES = %w[beta production staging alpha qa development].freeze

    def self.app(thor)
      thor.option :slug, type: :string, required: true, desc: 'Application slug'
      thor.option :mode, type: :string, required: true, enum: MODES, desc: 'Application mode'
    end

    def self.page(thor)
      thor.option :offset, type: :numeric, desc: 'Number of results to skip'
      thor.option :limit, type: :numeric, desc: 'Maximum number of results to return'
    end

    def self.sort(thor, sort_by_enum: nil)
      thor.option :sort_by, type: :string, enum: sort_by_enum, desc: 'Sort field'
      thor.option :direction, type: :string, enum: %w[asc desc], desc: 'Sort direction'
    end

    def self.raw_filters(thor)
      thor.option :filters, type: :string,
                            desc: 'Raw filter JSON object, merged in (typed filter flags win on key conflicts)'
    end
  end

  class CrashesCLI < Thor
    SORT_FIELDS = %w[last_occurred_at occurrences_counter affected_users_counter
                     max_app_version min_app_version severity first_occurred_at].freeze

    desc 'list', 'List crashes for an application'
    long_desc(<<~DESC, wrap: false)
      List crashes for an application.

      Common filters have dedicated flags: --status, --platform, --type, --app-version.
      Pass any other supported filter as a JSON object via --filters:
        date_ms        {"gte": <ms>, "lte": <ms>}  occurrence time range
        status_id      [1,2,3]  (1=open 2=closed 3=in_progress)
        teams          ["<team-id>", ...]
        app_versions   ["1.2.3", ...]
        devices        ["iPhone15,2", ...]
        os_versions    ["17.4", ...]
        platform       ["IOS","ANDROID","DART","JAVASCRIPT"]
        current_views  ["<screen-name>", ...]
        type           ["CRASH","ANR","OOM","NON_FATAL","APP_HANG","FORCE_RESTART"]
                       (force restarts are listed only when FORCE_RESTART is given)
        subtype        ["CRITICAL","ERROR","WARNING","INFO"]  (needs NON_FATAL in type)
        feature_flags  ["<flag>" or "<flag> -> <variant>", ...]

      Example: --filters '{"devices":["iPhone15,2"],"type":["NON_FATAL"]}'
    DESC
    QueryOptions.app(self)
    QueryOptions.page(self)
    QueryOptions.sort(self, sort_by_enum: SORT_FIELDS)
    option :status, type: :array, enum: %w[open closed in_progress], desc: 'Filter by status'
    option :platform, type: :array, enum: %w[IOS ANDROID DART JAVASCRIPT], desc: 'Filter by platform'
    option :type, type: :array, enum: %w[CRASH ANR OOM NON_FATAL APP_HANG FORCE_RESTART], desc: 'Filter by crash type'
    option :app_version, type: :array, desc: 'Filter by app version(s)'
    QueryOptions.raw_filters(self)
    def list
      Commands::Query.new(options).crashes_list
    end

    desc 'show', 'Show details for a single crash'
    QueryOptions.app(self)
    option :number, type: :numeric, required: true, desc: 'Crash number'
    def show
      Commands::Query.new(options).crash_show(options[:number])
    end

    desc 'patterns', 'Show crash patterns for a single crash'
    long_desc(<<~DESC, wrap: false)
      Show crash patterns (grouped dimensions) for a single crash.

      Typed flags: --pattern-key, --sort-by, --direction. Other filters via --filters:
        date_ms       {"gte": <ms>, "lte": <ms>}
        app_versions  ["1.2.3", ...]
        devices       ["iPhone15,2", ...]
        os_versions   ["17.4", ...]
    DESC
    QueryOptions.app(self)
    option :number, type: :numeric, required: true, desc: 'Crash number'
    option :pattern_key, type: :string,
                         enum: %w[app_versions devices oses current_views app_status experiments],
                         desc: 'Pattern dimension'
    option :sort_by, type: :string, enum: %w[occurrences_count last_seen first_seen], desc: 'Sort field'
    option :direction, type: :string, enum: %w[asc desc], desc: 'Sort direction'
    QueryOptions.raw_filters(self)
    def patterns
      Commands::Query.new(options).crash_patterns(options[:number])
    end

    desc 'diagnostics', 'Show diagnostics for a single crash'
    QueryOptions.app(self)
    option :number, type: :numeric, required: true, desc: 'Crash number'
    def diagnostics
      Commands::Query.new(options).crash_diagnostics(options[:number])
    end

    desc 'occurrence-tokens', 'List occurrence tokens for a crash'
    long_desc(<<~DESC, wrap: false)
      List occurrence tokens for a crash (paginate with --current-token / --direction).

      Filters via --filters:
        date_ms        {"gte": <ms>, "lte": <ms>}
        app_versions   ["1.2.3", ...]
        app_status     "foreground" | "background"
        devices        ["iPhone15,2", ...]
        os_versions    ["17.4", ...]
        experiments    ["<experiment>", ...]
        current_views  ["<screen-name>", ...]
    DESC
    QueryOptions.app(self)
    option :number, type: :numeric, required: true, desc: 'Crash number'
    option :current_token, type: :string, desc: 'Pagination cursor token'
    option :direction, type: :string, enum: %w[first last], desc: 'Pagination direction'
    QueryOptions.raw_filters(self)
    def occurrence_tokens
      Commands::Query.new(options).occurrence_tokens(options[:number])
    end

    desc 'occurrence', 'Show details for a single crash occurrence'
    QueryOptions.app(self)
    option :number, type: :numeric, required: true, desc: 'Crash number'
    option :ulid, type: :string, required: true, desc: 'State/occurrence ULID token'
    def occurrence
      Commands::Query.new(options).occurrence_details(options[:number], options[:ulid])
    end
  end

  class BugsCLI < Thor
    desc 'list', 'List bugs for an application'
    long_desc(<<~DESC, wrap: false)
      List bugs for an application.

      Common filters have dedicated flags: --status, --priority, --app-version.
      Pass any other supported filter as a JSON object via --filters:
        status_id    [1,2,3]  (1=New 2=Closed 3=In Progress)
        priority_id  [-1,1,2,3,4]  (-1=N/A 1=Trivial 2=Minor 3=Major 4=Blocker)
        app_version  ["1.2.3", ...]
        platform     ["ios","android"]  (cross-platform apps)
        type         ["<type>", ...]
        tag          [["login","auth"], ...]  (inner array OR-ed, groups AND-ed)
        category     [["UI"], ...]
        devices      ["iPhone 15 Pro", ...]
        os_versions  ["iOS 17.0", ...]
        experiments  ["<flag>", ...]
        reported_at  {"from": <ms>, "to": <ms>}
    DESC
    QueryOptions.app(self)
    QueryOptions.page(self)
    QueryOptions.sort(self)
    option :status, type: :array, enum: %w[new closed in_progress], desc: 'Filter by status'
    option :priority, type: :array, enum: %w[na trivial minor major blocker], desc: 'Filter by priority'
    option :app_version, type: :array, desc: 'Filter by app version(s)'
    QueryOptions.raw_filters(self)
    def list
      Commands::Query.new(options).bugs_list
    end

    desc 'show', 'Show details for a single bug'
    QueryOptions.app(self)
    option :number, type: :numeric, required: true, desc: 'Bug number'
    def show
      Commands::Query.new(options).bug_show(options[:number])
    end

    desc 'update', 'Update a bug (status, priority, tags, or mark duplicate)'
    long_desc(<<~DESC, wrap: false)
      Update a bug. Provide at least one change: --status/--priority/--tags/--clear-tags
      change the bug; duplicate marking is a separate action and can't be combined with them.

      Tags: --tags appends to the existing tags by default. Use --tag-action to change
      that: replace sets --tags as the full list (removing others); remove deletes --tags
      and keeps the rest. --clear-tags removes all tags.

      Mark a duplicate: --duplicate-of <master-number> (implies --action mark_as_duplicate).
      Detach a duplicate: --action unmark_as_duplicate.
    DESC
    QueryOptions.app(self)
    option :number, type: :numeric, required: true, desc: 'Bug number'
    option :status, type: :string, enum: %w[new closed in_progress], desc: 'New status'
    option :priority, type: :string, enum: %w[na trivial minor major blocker], desc: 'New priority'
    option :tags, type: :array, desc: 'Tags to apply (see --tag-action; appends to existing tags by default)'
    option :tag_action, type: :string, enum: %w[replace append remove],
                        desc: 'How --tags is applied: append (default, keep existing), replace, remove'
    option :clear_tags, type: :boolean, desc: 'Remove all tags (cannot be combined with --tag-action)'
    option :duplicate_of, type: :numeric, desc: 'Master bug number (marks this a duplicate)'
    option :action, type: :string, enum: %w[mark_as_duplicate unmark_as_duplicate],
                    desc: 'Duplicate action (defaults to mark_as_duplicate with --duplicate-of)'
    def update
      Commands::Query.new(options).bug_update(options[:number])
    end
  end

  class ApmCLI < Thor
    METRICS = %w[network launch flows screen_loading frame_drop].freeze
    GROUP_METRICS = (METRICS + %w[funnels]).freeze

    desc 'groups', 'Rank APM groups worst-first for an application'
    long_desc(<<~DESC, wrap: false)
      Rank APM groups worst-first. --metric is required (network, launch, flows,
      screen_loading, frame_drop, funnels).

      --sort is a JSON object {"by": <field>, "direction": "asc"|"desc"}; the CLI
      wraps it in the single-item array the API expects.
        by: failure_rate, p95, p50, apdex, apdex_change, occurrences, dissat_count,
            frozen_frames_percent, slow_frames_percent, count, conversion, drop_off, median_time

      --filters is a JSON object. Common keys: date_ms {"gte","lte"},
      app_version ["1.2.3"], platform ["ios","android"], group_name, key_metric,
      count, dissat_count, apdex, apdex_change, teams. Available filters vary by
      --metric; see the Luciq API docs for the full per-metric set.
    DESC
    QueryOptions.app(self)
    option :metric, type: :string, required: true, enum: GROUP_METRICS, desc: 'APM metric'
    QueryOptions.page(self)
    option :sort, type: :string, desc: 'Sort JSON object {"by":...,"direction":...} (wrapped in a 1-item array)'
    QueryOptions.raw_filters(self)
    def groups
      Commands::Query.new(options).apm_groups
    end

    desc 'group', 'Fetch APM panels for a single group'
    long_desc(<<~DESC, wrap: false)
      Fetch APM panels (charts/tables/summary) for a single group. --metric is
      required; identify the group with --group-uuid or --group-url. --method
      applies to the network metric.

      --views is a JSON array selecting which panels/tables to return (defaults to ["summary"]).
      --filters is a JSON object; keys vary by metric and include date_ms,
      app_version, platform ["ios","android"], device, os_version, country,
      carrier, radio, failure_name, failure_type, response_time_ms,
      custom_attributes, experiment. See the Luciq API docs for the full schema.
    DESC
    QueryOptions.app(self)
    option :metric, type: :string, required: true, enum: GROUP_METRICS, desc: 'APM metric'
    option :group_uuid, type: :string, desc: 'Group UUID (or use --group-url)'
    option :group_url, type: :string, desc: 'Group URL (or use --group-uuid)'
    option :method, type: :string, enum: %w[GET POST PUT PATCH DELETE HEAD OPTIONS], desc: 'HTTP method (network)'
    option :views, type: :string, desc: 'Views JSON array (defaults to ["summary"])'
    QueryOptions.raw_filters(self)
    def group
      Commands::Query.new(options).apm_group
    end

    desc 'occurrence', 'Inspect APM occurrences in a group'
    long_desc(<<~DESC, wrap: false)
      Inspect APM occurrences in a group. --metric and --selector
      (worst/by_token/list) are required; identify the group with --group-uuid or
      --group-url. For by_token pass --token; for list paginate with
      --current-token / --direction / --limit.

      --filters is a JSON object; keys vary by metric and include date_ms,
      app_version, platform ["ios","android"], device, os_version, country,
      carrier, radio, failure_name, failure_type, response_time_ms,
      latency_percentile, experiment. See the Luciq API docs for the full schema.
    DESC
    QueryOptions.app(self)
    option :metric, type: :string, required: true, enum: METRICS, desc: 'APM metric'
    option :selector, type: :string, required: true, enum: %w[worst by_token list], desc: 'Occurrence selector'
    option :group_uuid, type: :string, desc: 'Group UUID (or use --group-url)'
    option :group_url, type: :string, desc: 'Group URL (or use --group-uuid)'
    option :method, type: :string, enum: %w[GET POST PUT PATCH DELETE HEAD OPTIONS], desc: 'HTTP method (network)'
    option :token, type: :string, desc: 'Occurrence token (for by_token)'
    option :current_token, type: :string, desc: 'Pagination cursor token (for list)'
    option :direction, type: :string, enum: %w[first last], desc: 'Pagination direction (for list)'
    option :limit, type: :numeric, desc: 'Maximum number of occurrences (for list)'
    QueryOptions.raw_filters(self)
    def occurrence
      Commands::Query.new(options).apm_occurrence
    end

    desc 'funnel-events', 'List pickable events for building funnels'
    long_desc(<<~DESC, wrap: false)
      List events (network / screen_loading groups) that can be added to a funnel.
      Narrow with --event-type and/or a name substring via --q.
    DESC
    QueryOptions.app(self)
    option :event_type, type: :string, enum: %w[network screen_loading], desc: 'Event type (default: all)'
    option :q, type: :string, desc: 'Case-insensitive name substring'
    option :limit, type: :numeric, desc: 'Max events per type (1-25, default 20)'
    def funnel_events
      Commands::Query.new(options).apm_funnel_events
    end

    desc 'funnel-create', 'Create a funnel'
    long_desc(<<~DESC, wrap: false)
      Create a funnel from 2-20 events. --events is a JSON array; each step is one of:
        {"type":"network","ulid":"<event-ulid>"}
        {"type":"screen_loading","ulid":"<event-ulid>"}
        {"type":"user_event","name":"<event-name>"}
    DESC
    QueryOptions.app(self)
    option :name, type: :string, required: true, desc: 'Funnel name'
    option :events, type: :string, required: true, desc: 'Steps JSON array (2-20 items)'
    def funnel_create
      Commands::Query.new(options).apm_funnel_create
    end

    desc 'funnel-update', 'Update a funnel'
    long_desc(<<~DESC, wrap: false)
      Update a funnel. --events (a JSON array of steps, same shape as funnel-create)
      replaces the funnel's full step set.
    DESC
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Funnel ULID'
    option :name, type: :string, desc: 'Funnel name'
    option :events, type: :string, desc: 'Steps JSON array (replaces the full set)'
    def funnel_update
      Commands::Query.new(options).apm_funnel_update
    end

    desc 'funnel-delete', 'Delete a funnel'
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Funnel ULID'
    def funnel_delete
      Commands::Query.new(options).apm_funnel_delete
    end
  end

  class ReviewsCLI < Thor
    desc 'list', 'List reviews for an application'
    long_desc(<<~DESC, wrap: false)
      List reviews for an application.

      Typed flags: --rating (1-5), --country, --os (ios/android), --sort-by (date),
      --sort-direction. Other filters via --filters:
        date_ms      {"gte": <ms>, "lte": <ms>}
        app_version  ["1.2.3", ...]
        prompt_type  ["custom","native","app_store"]
    DESC
    QueryOptions.app(self)
    QueryOptions.page(self)
    option :sort_by, type: :string, enum: %w[date], desc: 'Sort field'
    option :sort_direction, type: :string, enum: %w[asc desc], desc: 'Sort direction'
    option :rating, type: :array, enum: %w[1 2 3 4 5], desc: 'Filter by rating(s) 1-5'
    option :country, type: :array, desc: 'Filter by country/countries'
    option :os, type: :array, enum: %w[ios android], desc: 'Filter by OS'
    QueryOptions.raw_filters(self)
    def list
      Commands::Query.new(options).reviews_list
    end
  end

  class SurveysCLI < Thor
    desc 'list', 'List surveys for an application'
    long_desc(<<~DESC, wrap: false)
      List surveys for an application.

      Typed flags --type (0=custom 1=nps 2=app_store) and --status (0=draft
      1=published 2=paused). The raw --filters object accepts the same keys:
      {"type": [0,1,2], "status": [0,1,2]}.
    DESC
    QueryOptions.app(self)
    QueryOptions.page(self)
    option :type, type: :array, enum: %w[0 1 2], desc: 'Filter by type (0=custom 1=nps 2=app_store)'
    option :status, type: :array, enum: %w[0 1 2], desc: 'Filter by status (0=draft 1=published 2=paused)'
    QueryOptions.raw_filters(self)
    def list
      Commands::Query.new(options).surveys_list
    end

    desc 'show', 'Show a survey\'s details and response statistics'
    long_desc(<<~DESC, wrap: false)
      Show a survey's questions and response statistics. Paginate responses with --page.

      Filters via --filters:
        date_ms          {"gte": <ms>, "lte": <ms>}
        search_words     "<free text>"
        response_status  [0,1]
        nps              <0-10>
        locale           "<locale>"
        app_versions     ["1.2.3", ...]
        devices          ["iPhone15,2", ...]
        os_versions      ["17.4", ...]
        countries        ["US", ...]
        platforms        ["ios","android"]
    DESC
    QueryOptions.app(self)
    option :id, type: :numeric, required: true, desc: 'Survey id'
    option :page, type: :numeric, desc: 'Responses page number'
    QueryOptions.raw_filters(self)
    def show
      Commands::Query.new(options).survey_show(options[:id])
    end
  end

  class AppsCLI < Thor
    desc 'list', 'List applications accessible to the authenticated developer'
    QueryOptions.page(self)
    option :platform, type: :string, enum: %w[ios android react_native flutter], desc: 'Filter by platform'
    def list
      Commands::Query.new(options).apps_list
    end
  end

  class IssuesCLI < Thor
    desc 'list', 'List issues across sources ranked by impact'
    long_desc(<<~DESC, wrap: false)
      List issues across crashes, APM, AI, and bugs, ranked by Apdex impact.

      Typed flags: --limit, --sort-by (apdex_impact/occurrences_counter),
      --sort-direction, --top-issues (curated shortlist). --pagination is a JSON
      object of per-source cursor tokens. Other filters via --filters:
        date_ms          {"gte": <ms>, "lte": <ms>}  (>= 24h span)
        search_tokens    ["<text>", ...]
        app_version      ["1.2.3", ...]
        teams            ["<team-id>", ...]
        platform         ["IOS","ANDROID","DART","JAVASCRIPT"]
        apm_types        ["networks","traces","launches","screen_loadings","frame_drops"]
        crashes_types    ["CRASH","ANR","OOM","NON_FATAL"]
        ai_issues_types  ["visual_issue","broken_functionality"]
        bugs_types       ["<type>", ...]
        apdex_severity   ["high","medium","low","no_impact"]
    DESC
    QueryOptions.app(self)
    option :limit, type: :numeric, desc: 'Maximum number of issues (1-50)'
    option :sort_by, type: :string, enum: %w[apdex_impact occurrences_counter], desc: 'Sort field'
    option :sort_direction, type: :string, enum: %w[asc desc], desc: 'Sort direction'
    option :top_issues, type: :boolean, desc: 'Return a curated shortlist'
    option :pagination, type: :string, desc: 'Per-source cursor tokens JSON object'
    QueryOptions.raw_filters(self)
    def list
      Commands::Query.new(options).issues_list
    end
  end

  class OpportunitiesCLI < Thor
    desc 'list', 'List opportunities for an application'
    long_desc(<<~DESC, wrap: false)
      List opportunities ranked by priority then recency.

      Typed flags --status, --priority, --team-id map into the same filter keys:
        status    ["open","in_progress","closed","dismissed"]
        priority  ["1","2","3","4","unset"]
        team_id   "<team-ulid>" | "unassigned"
    DESC
    QueryOptions.app(self)
    QueryOptions.page(self)
    option :status, type: :array, enum: %w[open in_progress closed dismissed], desc: 'Filter by status'
    option :priority, type: :array, enum: %w[1 2 3 4 unset], desc: 'Filter by priority'
    option :team_id, type: :string, desc: 'Filter by team ULID or "unassigned"'
    QueryOptions.raw_filters(self)
    def list
      Commands::Query.new(options).opportunities_list
    end

    desc 'show', 'Show details for a single opportunity'
    QueryOptions.app(self)
    option :id, type: :numeric, required: true, desc: 'Opportunity id'
    def show
      Commands::Query.new(options).opportunity_show(options[:id])
    end
  end

  class AlertsCLI < Thor
    desc 'list', 'List alert rules'
    QueryOptions.app(self)
    option :sort_by, type: :string,
                     enum: %w[latest_creation_date last_edit_date highest_triggered_count],
                     desc: 'Sort field'
    option :sort_direction, type: :string, enum: %w[asc desc], desc: 'Sort direction'
    def list
      Commands::Query.new(options).alerts_list
    end

    desc 'show', 'Show a single alert rule'
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Alert ULID (e.g. crashes_01HX...)'
    def show
      Commands::Query.new(options).alert_show(options[:ulid])
    end

    desc 'init', 'Show the menu (types, triggers, conditions, actions) for building rules'
    QueryOptions.app(self)
    def init
      Commands::Query.new(options).alerts_init
    end

    desc 'create', 'Create an alert rule'
    long_desc(<<~DESC, wrap: false)
      Create an alert rule. Run `luciq alerts init` first for the valid types,
      triggers, conditions, and actions, then pass the rule body as --payload JSON:
        {"type":"Crashes","trigger":"<trigger>","title":"...","operation":0,
         "conditions":[...],"actions":[...],"rule_owner":"<team-id>"}
    DESC
    QueryOptions.app(self)
    option :payload, type: :string, required: true, desc: 'Rule body JSON object'
    def create
      Commands::Query.new(options).alert_create
    end

    desc 'update', 'Update an alert rule'
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Alert ULID'
    option :payload, type: :string, required: true, desc: 'Rule body JSON object'
    def update
      Commands::Query.new(options).alert_update(options[:ulid])
    end

    desc 'delete', 'Delete an alert rule'
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Alert ULID'
    def delete
      Commands::Query.new(options).alert_delete(options[:ulid])
    end
  end

  class IncidentsCLI < Thor
    desc 'list', 'List triggered alerts (incidents)'
    long_desc(<<~DESC, wrap: false)
      List triggered alerts. Typed flags: --sort-by, --sort-direction, --status,
      --type. Other filters via --filters:
        date_ms  {"gte": <ms>, "lte": <ms>}
        title    ["<token>", ...]
      Status: open, manual_resolve, automatic_resolve.
      Type: overall_app, launch, screen_loading, network, trace, frame_drop, crash,
            anr, oom, non_fatal, fatal_ui_hang, feature_experiment.
    DESC
    QueryOptions.app(self)
    QueryOptions.page(self)
    option :sort_by, type: :string, enum: %w[first_triggered last_triggered count], desc: 'Sort field'
    option :sort_direction, type: :string, enum: %w[asc desc], desc: 'Sort direction'
    option :status, type: :array, enum: %w[open manual_resolve automatic_resolve], desc: 'Filter by status'
    option :type, type: :array,
                  enum: %w[overall_app launch screen_loading network trace frame_drop crash anr oom
                           non_fatal fatal_ui_hang feature_experiment],
                  desc: 'Filter by incident type(s)'
    QueryOptions.raw_filters(self)
    def list
      Commands::Query.new(options).incidents_list
    end

    desc 'show', 'Show a single triggered alert'
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Incident ULID'
    def show
      Commands::Query.new(options).incident_show(options[:ulid])
    end

    desc 'resolve', 'Resolve a triggered alert'
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Incident ULID'
    def resolve
      Commands::Query.new(options).incident_resolve(options[:ulid])
    end

    desc 'reopen', 'Reopen a triggered alert'
    QueryOptions.app(self)
    option :ulid, type: :string, required: true, desc: 'Incident ULID'
    def reopen
      Commands::Query.new(options).incident_reopen(options[:ulid])
    end
  end
end
