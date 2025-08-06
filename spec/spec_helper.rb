# frozen_string_literal: true

require 'bundler/setup'
require 'elo_rankable'
require 'active_record'
require 'sqlite3'

# Set up in-memory SQLite database for testing
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Load the schema
ActiveRecord::Schema.define do
  create_table :elo_rankings do |t|
    t.references :rankable, polymorphic: true, null: false, index: true
    t.integer :rating, null: false, default: 1200
    t.integer :games_played, null: false, default: 0
    t.timestamps
  end

  add_index :elo_rankings, :rating
  add_index :elo_rankings, %i[rankable_type rankable_id], unique: true

  create_table :players do |t|
    t.string :name
    t.timestamps
  end

  create_table :teams do |t|
    t.string :name
    t.timestamps
  end
end

# Test models
class Player < ActiveRecord::Base
  has_elo_ranking
end

class Team < ActiveRecord::Base
  has_elo_ranking
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    # Clean up between tests
    EloRankable::EloRanking.delete_all
    Player.delete_all
    Team.delete_all
  end
end
