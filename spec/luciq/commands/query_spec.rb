# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Luciq::Commands::Query do
  let(:client) { instance_double(Luciq::API::Client) }

  before do
    ENV['LUCIQ_AUTH_TOKEN'] = 'token-123'
    allow(Luciq::API::Client).to receive(:new).and_return(client)
  end

  describe '#crashes_list' do
    it 'maps status names to ids and forwards pagination + typed filters' do
      options = { slug: 'my-app', mode: 'production', limit: 10,
                  status: %w[open in_progress], platform: ['IOS'] }

      expect(client).to receive(:invoke_tool).with(
        'list_crashes',
        hash_including(
          slug: 'my-app', mode: 'production', limit: 10,
          filters: { 'status_id' => [1, 3], 'platform' => ['IOS'] }
        )
      ).and_return({ 'crashes' => [] })

      expect { described_class.new(options).crashes_list }.to output(/crashes/).to_stdout
    end

    it 'merges the raw --filters JSON escape hatch' do
      options = { slug: 'a', mode: 'production', filters: '{"app_versions":["1.2.3"]}' }

      expect(client).to receive(:invoke_tool).with(
        'list_crashes', hash_including(filters: hash_including('app_versions' => ['1.2.3']))
      ).and_return({})

      expect { described_class.new(options).crashes_list }.to output.to_stdout
    end

    it 'lets a typed filter flag win over the same key in --filters' do
      options = { slug: 'a', mode: 'production', status: ['open'], filters: '{"status_id":[99]}' }

      expect(client).to receive(:invoke_tool).with(
        'list_crashes', hash_including(filters: hash_including('status_id' => [1]))
      ).and_return({})

      expect { described_class.new(options).crashes_list }.to output.to_stdout
    end

    it 'exits with an error on invalid --filters JSON' do
      options = { slug: 'a', mode: 'production', filters: 'not-json' }

      expect { described_class.new(options).crashes_list }
        .to output(/Invalid --filters JSON/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe '#crash_show' do
    it 'forwards the crash number to crash_details' do
      expect(client).to receive(:invoke_tool)
        .with('crash_details', hash_including(slug: 'a', mode: 'production', number: 42))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).crash_show(42) }.to output.to_stdout
    end
  end

  describe '#bug_update' do
    it 'maps status/priority names to ids and forwards tags' do
      options = { slug: 'a', mode: 'production', status: 'closed', priority: 'major', tags: ['regression'] }

      expect(client).to receive(:invoke_tool).with(
        'update_bug',
        hash_including(slug: 'a', mode: 'production', number: 7,
                       status_id: 2, priority_id: 3, tags: ['regression'])
      ).and_return({})

      expect { described_class.new(options).bug_update(7) }.to output.to_stdout
    end

    it 'sends only the provided change as an exact hash, with no action key' do
      options = { slug: 'a', mode: 'production', status: 'closed' }

      expect(client).to receive(:invoke_tool)
        .with('update_bug', { slug: 'a', mode: 'production', number: 7, status_id: 2 })
        .and_return({})

      expect { described_class.new(options).bug_update(7) }.to output.to_stdout
    end

    it 'clears all tags when --clear-tags is set (forces replace with an empty set)' do
      options = { slug: 'a', mode: 'production', clear_tags: true }

      expect(client).to receive(:invoke_tool)
        .with('update_bug', { slug: 'a', mode: 'production', number: 7, tags: [], tag_action: 'replace' })
        .and_return({})

      expect { described_class.new(options).bug_update(7) }.to output.to_stdout
    end

    it 'refuses a no-op update with no change flags' do
      expect(client).not_to receive(:invoke_tool)
      expect { described_class.new({ slug: 'a', mode: 'production' }).bug_update(7) }
        .to output(/at least one change/).to_stdout.and raise_error(SystemExit)
    end

    it 'forwards tag_action when appending tags' do
      options = { slug: 'a', mode: 'production', tags: ['regression'], tag_action: 'append' }

      expect(client).to receive(:invoke_tool).with(
        'update_bug',
        hash_including(slug: 'a', mode: 'production', number: 7, tags: ['regression'], tag_action: 'append')
      ).and_return({})

      expect { described_class.new(options).bug_update(7) }.to output.to_stdout
    end

    it 'forwards tag_action when removing tags' do
      options = { slug: 'a', mode: 'production', tags: ['stale'], tag_action: 'remove' }

      expect(client).to receive(:invoke_tool).with(
        'update_bug',
        hash_including(slug: 'a', mode: 'production', number: 7, tags: ['stale'], tag_action: 'remove')
      ).and_return({})

      expect { described_class.new(options).bug_update(7) }.to output.to_stdout
    end

    it 'rejects combining --clear-tags with --tag-action' do
      options = { slug: 'a', mode: 'production', clear_tags: true, tag_action: 'append' }

      expect(client).not_to receive(:invoke_tool)
      expect { described_class.new(options).bug_update(7) }
        .to output(/clear-tags cannot be combined with --tag-action/).to_stdout.and raise_error(SystemExit)
    end

    it 'refuses --tag-action passed without any change' do
      expect(client).not_to receive(:invoke_tool)
      expect { described_class.new({ slug: 'a', mode: 'production', tag_action: 'remove' }).bug_update(7) }
        .to output(/at least one change/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe '#apm_groups' do
    it 'forwards the metric and wraps the --sort object in a single-element array' do
      options = { slug: 'a', mode: 'production', metric: 'funnels',
                  sort: '{"by":"failure_rate","direction":"desc"}' }

      expect(client).to receive(:invoke_tool).with(
        'apm_list_groups',
        hash_including(slug: 'a', mode: 'production', metric: 'funnels',
                       sort: [{ 'by' => 'failure_rate', 'direction' => 'desc' }])
      ).and_return({})

      expect { described_class.new(options).apm_groups }.to output.to_stdout
    end
  end

  describe '#apm_group' do
    it 'defaults views to ["summary"] when --views is omitted' do
      options = { slug: 'a', mode: 'production', metric: 'network', group_uuid: 'g1' }

      expect(client).to receive(:invoke_tool).with(
        'apm_group_view', hash_including(metric: 'network', group_uuid: 'g1', views: ['summary'])
      ).and_return({})

      expect { described_class.new(options).apm_group }.to output.to_stdout
    end

    it 'parses a provided --views JSON array' do
      options = { slug: 'a', mode: 'production', metric: 'network', views: '["summary","spans_table"]' }

      expect(client).to receive(:invoke_tool).with(
        'apm_group_view', hash_including(views: %w[summary spans_table])
      ).and_return({})

      expect { described_class.new(options).apm_group }.to output.to_stdout
    end

    it 'identifies the group by --group-url when --group-uuid is absent' do
      options = { slug: 'a', mode: 'production', metric: 'network', group_url: 'https://example.com/x' }

      expect(client).to receive(:invoke_tool).with(
        'apm_group_view', hash_including(metric: 'network', group_url: 'https://example.com/x')
      ).and_return({})

      expect { described_class.new(options).apm_group }.to output.to_stdout
    end
  end

  describe '#apm_occurrence' do
    it 'forwards selector and direction for list paging' do
      options = { slug: 'a', mode: 'production', metric: 'network', selector: 'list', direction: 'last' }

      expect(client).to receive(:invoke_tool).with(
        'apm_occurrence', hash_including(metric: 'network', selector: 'list', direction: 'last')
      ).and_return({})

      expect { described_class.new(options).apm_occurrence }.to output.to_stdout
    end
  end

  describe '#apps_list' do
    it 'invokes list_applications without slug/mode' do
      expect(client).to receive(:invoke_tool).with('list_applications', { platform: 'ios' })
                                             .and_return({})

      expect { described_class.new({ platform: 'ios' }).apps_list }.to output.to_stdout
    end
  end

  describe '#bug_update duplicate marking' do
    it 'defaults action to mark_as_duplicate when --duplicate-of is given' do
      options = { slug: 'a', mode: 'production', duplicate_of: 99 }

      expect(client).to receive(:invoke_tool).with(
        'update_bug', hash_including(number: 7, action: 'mark_as_duplicate', original_bug_number: 99)
      ).and_return({})

      expect { described_class.new(options).bug_update(7) }.to output.to_stdout
    end

    it 'forwards an explicit unmark_as_duplicate action' do
      options = { slug: 'a', mode: 'production', action: 'unmark_as_duplicate' }

      expect(client).to receive(:invoke_tool).with(
        'update_bug', hash_including(number: 7, action: 'unmark_as_duplicate')
      ).and_return({})

      expect { described_class.new(options).bug_update(7) }.to output.to_stdout
    end

    it 'rejects combining a duplicate action with --status/--priority' do
      options = { slug: 'a', mode: 'production', status: 'closed', duplicate_of: 99 }

      expect(client).not_to receive(:invoke_tool)
      expect { described_class.new(options).bug_update(7) }
        .to output(/cannot be combined/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe '#issues_list' do
    it 'forwards sort, top_issues, --pagination JSON and --filters' do
      options = { slug: 'a', mode: 'production', limit: 5, sort_by: 'apdex_impact',
                  sort_direction: 'desc', top_issues: true,
                  pagination: '{"bugs_pagination_token":3}', filters: '{"platform":["IOS"]}' }

      expect(client).to receive(:invoke_tool).with(
        'list_issues',
        hash_including(slug: 'a', mode: 'production', limit: 5, sort_by: 'apdex_impact',
                       sort_direction: 'desc', top_issues: true,
                       pagination: { 'bugs_pagination_token' => 3 },
                       filters: hash_including('platform' => ['IOS']))
      ).and_return({})

      expect { described_class.new(options).issues_list }.to output.to_stdout
    end
  end

  describe '#opportunities_list' do
    it 'maps status/priority/team_id into filters' do
      options = { slug: 'a', mode: 'production', status: ['open'], priority: %w[1 2], team_id: 'unassigned' }

      expect(client).to receive(:invoke_tool).with(
        'list_opportunities',
        hash_including(filters: { 'status' => ['open'], 'priority' => %w[1 2], 'team_id' => 'unassigned' })
      ).and_return({})

      expect { described_class.new(options).opportunities_list }.to output.to_stdout
    end
  end

  describe '#opportunity_show' do
    it 'forwards the opportunity id' do
      expect(client).to receive(:invoke_tool)
        .with('opportunity_details', hash_including(slug: 'a', mode: 'production', id: 12))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).opportunity_show(12) }.to output.to_stdout
    end
  end

  describe '#apm_funnel_events' do
    it 'forwards event_type, q and limit' do
      options = { slug: 'a', mode: 'production', event_type: 'network', q: 'login', limit: 10 }

      expect(client).to receive(:invoke_tool).with(
        'apm_funnel_events', hash_including(event_type: 'network', q: 'login', limit: 10)
      ).and_return({})

      expect { described_class.new(options).apm_funnel_events }.to output.to_stdout
    end
  end

  describe 'apm funnels (write)' do
    it 'creates a funnel with name and parsed --events' do
      options = { slug: 'a', mode: 'production', name: 'Checkout',
                  events: '[{"type":"user_event","name":"start"},{"type":"network","ulid":"x"}]' }

      expect(client).to receive(:invoke_tool).with(
        'apm_funnel_write',
        hash_including(operation: 'create', name: 'Checkout',
                       events: [{ 'type' => 'user_event', 'name' => 'start' },
                                { 'type' => 'network', 'ulid' => 'x' }])
      ).and_return({})

      expect { described_class.new(options).apm_funnel_create }.to output.to_stdout
    end

    it 'updates a funnel with ulid and events' do
      options = { slug: 'a', mode: 'production', ulid: 'f1', events: '[{"type":"network","ulid":"x"}]' }

      expect(client).to receive(:invoke_tool).with(
        'apm_funnel_write',
        hash_including(operation: 'update', ulid: 'f1', events: [{ 'type' => 'network', 'ulid' => 'x' }])
      ).and_return({})

      expect { described_class.new(options).apm_funnel_update }.to output.to_stdout
    end

    it 'deletes a funnel by ulid' do
      expect(client).to receive(:invoke_tool)
        .with('apm_funnel_write', hash_including(operation: 'delete', ulid: 'f1'))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production', ulid: 'f1' }).apm_funnel_delete }.to output.to_stdout
    end
  end

  describe 'alerts' do
    it 'lists with the list action and sort' do
      options = { slug: 'a', mode: 'production', sort_by: 'last_edit_date', sort_direction: 'asc' }

      expect(client).to receive(:invoke_tool).with(
        'read_alerts', hash_including(action: 'list', sort_by: 'last_edit_date', sort_direction: 'asc')
      ).and_return({})

      expect { described_class.new(options).alerts_list }.to output.to_stdout
    end

    it 'shows a rule with the details action and ulid' do
      expect(client).to receive(:invoke_tool)
        .with('read_alerts', hash_including(action: 'details', ulid: 'crashes_01HX'))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).alert_show('crashes_01HX') }
        .to output.to_stdout
    end

    it 'fetches the init menu' do
      expect(client).to receive(:invoke_tool).with('read_alerts', hash_including(action: 'init')).and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).alerts_init }.to output.to_stdout
    end

    it 'creates a rule by merging the --payload body at the top level' do
      options = { slug: 'a', mode: 'production', payload: '{"type":"Crashes","title":"t"}' }

      expect(client).to receive(:invoke_tool).with(
        'write_alerts', hash_including(action: 'create', type: 'Crashes', title: 't')
      ).and_return({})

      expect { described_class.new(options).alert_create }.to output.to_stdout
    end

    it 'updates a rule with ulid and payload' do
      options = { slug: 'a', mode: 'production', payload: '{"title":"t2"}' }

      expect(client).to receive(:invoke_tool).with(
        'write_alerts', hash_including(action: 'update', ulid: 'crashes_01HX', title: 't2')
      ).and_return({})

      expect { described_class.new(options).alert_update('crashes_01HX') }.to output.to_stdout
    end

    it 'deletes a rule by ulid' do
      expect(client).to receive(:invoke_tool)
        .with('write_alerts', hash_including(action: 'delete', ulid: 'crashes_01HX'))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).alert_delete('crashes_01HX') }
        .to output.to_stdout
    end
  end

  describe 'incidents' do
    it 'lists with the list action, sort and status/type filters' do
      options = { slug: 'a', mode: 'production', sort_by: 'count', status: ['open'], type: ['crash'] }

      expect(client).to receive(:invoke_tool).with(
        'read_incidents',
        hash_including(action: 'list', sort_by: 'count',
                       filters: { 'status' => ['open'], 'type' => ['crash'] })
      ).and_return({})

      expect { described_class.new(options).incidents_list }.to output.to_stdout
    end

    it 'shows an incident with the details action and ulid' do
      expect(client).to receive(:invoke_tool)
        .with('read_incidents', hash_including(action: 'details', ulid: 'inc_1'))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).incident_show('inc_1') }.to output.to_stdout
    end

    it 'resolves an incident' do
      expect(client).to receive(:invoke_tool)
        .with('write_incidents', hash_including(action: 'resolve', ulid: 'inc_1'))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).incident_resolve('inc_1') }.to output.to_stdout
    end

    it 'reopens an incident' do
      expect(client).to receive(:invoke_tool)
        .with('write_incidents', hash_including(action: 'reopen', ulid: 'inc_1'))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).incident_reopen('inc_1') }.to output.to_stdout
    end
  end

  describe '#crash_patterns' do
    it 'forwards number, pattern fields, and merges --filters' do
      options = { slug: 'a', mode: 'production', pattern_key: 'devices', sort_by: 'last_seen',
                  direction: 'asc', filters: '{"app_versions":["1.0"]}' }

      expect(client).to receive(:invoke_tool).with(
        'crash_patterns',
        hash_including(number: 9, pattern_key: 'devices', sort_by: 'last_seen', direction: 'asc',
                       filters: { 'app_versions' => ['1.0'] })
      ).and_return({})

      expect { described_class.new(options).crash_patterns(9) }.to output.to_stdout
    end
  end

  describe '#crash_diagnostics' do
    it 'forwards the crash number' do
      expect(client).to receive(:invoke_tool)
        .with('crash_diagnostics', { slug: 'a', mode: 'production', number: 9 })
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).crash_diagnostics(9) }.to output.to_stdout
    end
  end

  describe '#occurrence_tokens' do
    it 'forwards the cursor token and direction' do
      options = { slug: 'a', mode: 'production', current_token: 't', direction: 'last' }

      expect(client).to receive(:invoke_tool).with(
        'list_occurrences_tokens', hash_including(number: 9, current_token: 't', direction: 'last')
      ).and_return({})

      expect { described_class.new(options).occurrence_tokens(9) }.to output.to_stdout
    end
  end

  describe '#occurrence_details' do
    it 'forwards number and ulid' do
      expect(client).to receive(:invoke_tool)
        .with('get_occurrence_details', hash_including(number: 9, ulid: 'u1'))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).occurrence_details(9, 'u1') }.to output.to_stdout
    end
  end

  describe '#bugs_list' do
    it 'maps status/priority names to ids' do
      options = { slug: 'a', mode: 'production', status: ['new'], priority: %w[major blocker] }

      expect(client).to receive(:invoke_tool).with(
        'list_bugs', hash_including(filters: { 'status_id' => [1], 'priority_id' => [3, 4] })
      ).and_return({})

      expect { described_class.new(options).bugs_list }.to output.to_stdout
    end

    it 'omits the filters key entirely when no filter flags are given' do
      expect(client).to receive(:invoke_tool)
        .with('list_bugs', { slug: 'a', mode: 'production' })
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).bugs_list }.to output.to_stdout
    end
  end

  describe '#bug_show' do
    it 'forwards the bug number' do
      expect(client).to receive(:invoke_tool)
        .with('bug_details', hash_including(number: 5))
        .and_return({})

      expect { described_class.new({ slug: 'a', mode: 'production' }).bug_show(5) }.to output.to_stdout
    end
  end

  describe '#reviews_list' do
    it 'wraps --country in an array and coerces ratings to integers' do
      options = { slug: 'a', mode: 'production', rating: %w[4 5], country: 'US', os: ['ios'] }

      expect(client).to receive(:invoke_tool).with(
        'list_reviews',
        hash_including(filters: { 'rating' => [4, 5], 'country' => ['US'], 'os' => ['ios'] })
      ).and_return({})

      expect { described_class.new(options).reviews_list }.to output.to_stdout
    end
  end

  describe '#surveys_list' do
    it 'coerces type/status codes to integers' do
      options = { slug: 'a', mode: 'production', type: %w[0 1], status: ['2'] }

      expect(client).to receive(:invoke_tool).with(
        'list_surveys', hash_including(filters: { 'type' => [0, 1], 'status' => [2] })
      ).and_return({})

      expect { described_class.new(options).surveys_list }.to output.to_stdout
    end
  end

  describe '#survey_show' do
    it 'forwards id and page' do
      options = { slug: 'a', mode: 'production', page: 2 }

      expect(client).to receive(:invoke_tool).with(
        'survey_details', hash_including(id: 3, page: 2)
      ).and_return({})

      expect { described_class.new(options).survey_show(3) }.to output.to_stdout
    end
  end

  describe '#insights' do
    it 'merges --filters into app_insights' do
      options = { slug: 'a', mode: 'production', filters: '{"app_version":["1.0"]}' }

      expect(client).to receive(:invoke_tool).with(
        'app_insights', hash_including(filters: { 'app_version' => ['1.0'] })
      ).and_return({})

      expect { described_class.new(options).insights }.to output.to_stdout
    end
  end

  describe 'authentication guard' do
    it 'exits with "Not authenticated" when the token is blank' do
      ENV['LUCIQ_AUTH_TOKEN'] = '   '

      expect(client).not_to receive(:invoke_tool)
      expect { described_class.new({ slug: 'a', mode: 'production' }).crashes_list }
        .to output(/Not authenticated/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe 'JSON argument validation' do
    it 'exits with an error on invalid --events JSON' do
      options = { slug: 'a', mode: 'production', name: 'F', events: 'oops' }

      expect(client).not_to receive(:invoke_tool)
      expect { described_class.new(options).apm_funnel_create }
        .to output(/Invalid --events JSON/).to_stdout.and raise_error(SystemExit)
    end

    it 'rejects a --payload that is valid JSON but not an object' do
      options = { slug: 'a', mode: 'production', payload: '[1,2]' }

      expect(client).not_to receive(:invoke_tool)
      expect { described_class.new(options).alert_create }
        .to output(/must be a JSON object/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe 'non-JSON responses' do
    it 'prints a raw CSV response verbatim instead of JSON-encoding it' do
      csv = "rating,country\n5,US"
      allow(client).to receive(:invoke_tool).and_return(csv)

      expect { described_class.new({ slug: 'a', mode: 'production' }).reviews_list }
        .to output("#{csv}\n").to_stdout
    end
  end

  describe 'client error handling' do
    it 'prints a friendly message and exits when the client raises' do
      allow(client).to receive(:invoke_tool).and_raise('boom')

      expect { described_class.new({ slug: 'a', mode: 'production' }).crashes_list }
        .to output(/✗ boom/).to_stdout.and raise_error(SystemExit)
    end
  end
end
