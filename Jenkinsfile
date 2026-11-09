@Library('utils') _

ci(
  units: [[
    type: 'library',
    test: [
      container: [name: 'ruby', image: podCI.thirdParty('ruby:3.3'), size: 'small'],
      env: ['BUNDLE_PATH=/tmp/bundle', 'HOME=/tmp'],
      script: '''
      bundle install --jobs 4
      bundle exec rubocop
      bundle exec rspec -f p ${CI_RSPEC_JUNIT_FORMATTER:+--require "$CI_RSPEC_JUNIT_FORMATTER" -f LuciqJUnitFormatter -o "$CI_JUNIT_DIR/rspec.xml"}
    ''',
    ],
  ]],
)
