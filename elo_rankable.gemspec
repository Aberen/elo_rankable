# frozen_string_literal: true

require_relative 'lib/elo_rankable/version'

Gem::Specification.new do |spec|
  spec.name = 'elo_rankable'
  spec.version = EloRankable::VERSION
  spec.authors = ['Aberen']
  spec.email = ['nijoergensen@gmail.com']

  spec.summary = 'Add ELO rating capabilities to any ActiveRecord model'
  spec.description = 'Adds ELO rating to any ActiveRecord model via has_elo_ranking. It stores ratings in a separate EloRanking model to keep your host model clean, and provides domain-style methods for updating rankings after matches.'
  spec.homepage = 'https://github.com/Aberen/elo_rankable'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'activerecord', '>= 6.0', '< 8.0'
  spec.add_dependency 'activesupport', '>= 6.0', '< 8.0'
end
