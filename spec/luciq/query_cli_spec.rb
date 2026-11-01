# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Luciq::CrashesCLI do
  describe 'list --type' do
    it 'accepts FORCE_RESTART and passes it on to the query' do
      query = instance_double(Luciq::Commands::Query)
      expect(Luciq::Commands::Query).to receive(:new)
        .with(hash_including('type' => %w[CRASH FORCE_RESTART])).and_return(query)
      expect(query).to receive(:crashes_list)

      expect { Luciq::CLI.start(%w[crashes list --slug my-app --mode production --type CRASH FORCE_RESTART]) }
        .not_to raise_error
    end

    it 'still rejects an unknown type before any request' do
      expect(Luciq::Commands::Query).not_to receive(:new)

      expect { Luciq::CLI.start(%w[crashes list --slug my-app --mode production --type BOGUS]) }
        .to raise_error(SystemExit).and output(/Expected all values of '--type' to be one of .*; got BOGUS/).to_stderr
    end
  end
end

RSpec.describe Luciq::BugsCLI do
  describe 'update' do
    let(:client) { instance_double(Luciq::API::Client) }

    before do
      ENV['LUCIQ_AUTH_TOKEN'] = 'token-123'
      allow(Luciq::API::Client).to receive(:new).and_return(client)
    end

    # Thor would otherwise pass the option's own name, and post "comment" as the comment.
    %w[assignee team comment].each do |flag|
      it "reads a bare --#{flag} as blank and sends nothing" do
        expect(client).not_to receive(:invoke_tool)

        expect { Luciq::CLI.start(%W[bugs update --slug a --mode production --number 7 --#{flag} --status closed]) }
          .to output(/--#{flag} needs/).to_stdout.and raise_error(SystemExit)
      end
    end
  end
end
