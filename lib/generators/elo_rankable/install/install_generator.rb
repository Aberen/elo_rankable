# frozen_string_literal: true

require 'rails/generators/active_record'

module EloRankable
  module Generators
    class InstallGenerator < ActiveRecord::Generators::Base
      desc 'Create migration for EloRankable'

      source_root File.expand_path('templates', __dir__)

      def self.default_generator_root
        File.dirname(__FILE__)
      end

      def create_migration_file
        migration_template 'create_elo_rankings.rb', 'db/migrate/create_elo_rankings.rb'
      end
    end
  end
end
