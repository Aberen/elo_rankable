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

      # Validate input array
      raise ArgumentError, 'Players array cannot contain nil values' if players.any?(&:nil?)

      # Check for duplicates
      raise ArgumentError, 'Players array cannot contain duplicate players' if players.uniq.length != players.length

      # Validate all players respond to elo_ranking
      invalid_players = players.reject { |p| p.respond_to?(:elo_ranking) }
      raise ArgumentError, 'All players must respond to elo_ranking' unless invalid_players.empty?

      # Process all pairwise combinations
      players.each_with_index do |player1, i|
        players[(i + 1)..].each do |player2|
          player1.beat!(player2)
        end
      end
    end

    # Record a single winner vs all others match
    def record_winner_vs_all(winner, losers)
      # Validate winner
      raise ArgumentError, 'Winner cannot be nil' if winner.nil?
      raise ArgumentError, 'Winner must respond to elo_ranking' unless winner.respond_to?(:elo_ranking)

      # Validate losers array
      raise InvalidMatchError, 'Need at least 1 loser' if losers.empty?
      raise ArgumentError, 'Losers array cannot contain nil values' if losers.any?(&:nil?)
      raise InvalidMatchError, 'Winner cannot be in losers list' if losers.include?(winner)

      # Validate all losers respond to elo_ranking
      invalid_losers = losers.reject { |p| p.respond_to?(:elo_ranking) }
      raise ArgumentError, 'All losers must respond to elo_ranking' unless invalid_losers.empty?

      losers.each do |loser|
        winner.beat!(loser)
      end
    end

    # Record a draw between two players
    def record_draw(player1, player2)
      raise ArgumentError, 'Player1 cannot be nil' if player1.nil?
      raise ArgumentError, 'Player2 cannot be nil' if player2.nil?
      raise ArgumentError, 'Cannot record draw with same player' if player1 == player2
      raise ArgumentError, 'Player1 must respond to elo_ranking' unless player1.respond_to?(:elo_ranking)
      raise ArgumentError, 'Player2 must respond to elo_ranking' unless player2.respond_to?(:elo_ranking)

      Calculator.update_ratings_for_draw(player1, player2)
    end
  end
end

# Hook into ActiveRecord
ActiveRecord::Base.extend(EloRankable::HasEloRanking) if defined?(ActiveRecord::Base)
