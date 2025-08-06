# frozen_string_literal: true

require 'active_record'
require 'active_support'

require_relative 'elo_rankable/version'
require_relative 'elo_rankable/configuration'
require_relative 'elo_rankable/elo_ranking'
require_relative 'elo_rankable/calculator'
require_relative 'elo_rankable/has_elo_ranking'

module EloRankable
  class Error < StandardError; end
  class InvalidMatchError < Error; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield(config) if block_given?
    end

    # Record a multiplayer match where players are ranked by their position in the array
    # Higher-indexed players are treated as having lost to lower-indexed ones
    def record_multiplayer_match(players)
      raise InvalidMatchError, 'Need at least 2 players for a match' if players.length < 2

      # Process all pairwise combinations
      players.each_with_index do |player1, i|
        players[(i + 1)..].each do |player2|
          player1.beat!(player2)
        end
      end
    end

    # Record a single winner vs all others match
    def record_winner_vs_all(winner, losers)
      raise InvalidMatchError, 'Need at least 1 loser' if losers.empty?
      raise InvalidMatchError, 'Winner cannot be in losers list' if losers.include?(winner)

      losers.each do |loser|
        winner.beat!(loser)
      end
    end

    # Record a draw between two players
    def record_draw(player1, player2)
      Calculator.update_ratings_for_draw(player1, player2)
    end
  end
end

# Hook into ActiveRecord
ActiveRecord::Base.extend(EloRankable::HasEloRanking) if defined?(ActiveRecord::Base)
