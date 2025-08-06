# frozen_string_literal: true

module EloRankable
  module HasEloRanking
    def has_elo_ranking
      # Set up the polymorphic association
      has_one :elo_ranking, as: :rankable, class_name: 'EloRankable::EloRanking', dependent: :destroy

      # Include instance methods
      include InstanceMethods

      # Add scopes for leaderboards
      scope :by_elo_rating, -> { joins(:elo_ranking).order('elo_rankings.rating DESC') }
      scope :top_rated, ->(limit = 10) { by_elo_rating.limit(limit) }
    end

    module InstanceMethods
      def elo_ranking
        super || self.create_elo_ranking!(
          rating: EloRankable.config.base_rating,
          games_played: 0
        )
      end

      def elo_rating
        elo_ranking.rating
      end

      def games_played
        elo_ranking.games_played
      end

      # Domain-style DSL methods
      def beat!(other_player)
        validate_opponent!(other_player)
        EloRankable::Calculator.update_ratings_for_win(self, other_player)
      end

      def lost_to!(other_player)
        validate_opponent!(other_player)
        EloRankable::Calculator.update_ratings_for_win(other_player, self)
      end

      def draw_with!(other_player)
        validate_opponent!(other_player)
        EloRankable::Calculator.update_ratings_for_draw(self, other_player)
      end

      # Aliases for clarity
      alias elo_beat! beat!
      alias elo_lost_to! lost_to!
      alias elo_draw_with! draw_with!

      private

      def validate_opponent!(other_player)
        raise ArgumentError, "Cannot play against nil" if other_player.nil?
        raise ArgumentError, "Cannot play against yourself" if other_player == self
        raise ArgumentError, "Opponent must respond to elo_ranking" unless other_player.respond_to?(:elo_ranking)
      end
    end
  end
end
