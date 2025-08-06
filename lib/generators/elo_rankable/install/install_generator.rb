# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module EloRankable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc 'Create migration for EloRankable'

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def self.default_generator_root
        File.dirname(__FILE__)
      end

      def create_migration_file
        migration_template 'create_elo_rankings.rb', 'db/migrate/create_elo_rankings.rb'
      end
    end
  end
end
