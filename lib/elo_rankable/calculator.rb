# frozen_string_literal: true

module EloRankable
  class Calculator
    class << self
      # Calculate expected score for player A against player B
      def expected_score(rating_a, rating_b)
        1.0 / (1.0 + 10.0**((rating_b - rating_a) / 400.0))
      end

      # Update ratings after a match where player1 beats player2
      def update_ratings_for_win(winner, loser)
        winner_rating = winner.elo_ranking
        loser_rating = loser.elo_ranking

        winner_expected = expected_score(winner_rating.rating, loser_rating.rating)
        loser_expected = expected_score(loser_rating.rating, winner_rating.rating)

        winner_k = winner_rating.k_factor
        loser_k = loser_rating.k_factor

        # Winner gets 1 point, loser gets 0 points
        winner_new_rating = winner_rating.rating + winner_k * (1 - winner_expected)
        loser_new_rating = loser_rating.rating + loser_k * (0 - loser_expected)

        update_ranking(winner_rating, winner_new_rating)
        update_ranking(loser_rating, loser_new_rating)
      end

      # Update ratings after a draw
      def update_ratings_for_draw(player1, player2)
        player1_rating = player1.elo_ranking
        player2_rating = player2.elo_ranking

        player1_expected = expected_score(player1_rating.rating, player2_rating.rating)
        player2_expected = expected_score(player2_rating.rating, player1_rating.rating)

        player1_k = player1_rating.k_factor
        player2_k = player2_rating.k_factor

        # Both players get 0.5 points in a draw
        player1_new_rating = player1_rating.rating + player1_k * (0.5 - player1_expected)
        player2_new_rating = player2_rating.rating + player2_k * (0.5 - player2_expected)

        update_ranking(player1_rating, player1_new_rating)
        update_ranking(player2_rating, player2_new_rating)
      end

      private

      def update_ranking(elo_ranking, new_rating)
        elo_ranking.update!(
          rating: new_rating.round,
          games_played: elo_ranking.games_played + 1
        )
      end
    end
  end
end
