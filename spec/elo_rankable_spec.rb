# frozen_string_literal: true

require 'spec_helper'
require 'rspec-benchmark'

RSpec.configure do |config|
  config.include RSpec::Benchmark::Matchers
end

RSpec.describe EloRankable do
  let(:player1) { Player.create!(name: 'Alice') }
  let(:player2) { Player.create!(name: 'Bob') }
  let(:player3) { Player.create!(name: 'Charlie') }

  describe 'configuration' do
    it 'has a default base rating' do
      expect(EloRankable.config.base_rating).to eq(1200)
    end

    it 'allows configuration of base rating' do
      EloRankable.configure do |config|
        config.base_rating = 1500
      end

      expect(EloRankable.config.base_rating).to eq(1500)

      # Reset for other tests
      EloRankable.config.base_rating = 1200
    end

    it 'has a default k-factor strategy' do
      # Test the default tiered k-factor
      expect(EloRankable.config.k_factor_for(1000)).to eq(32)
      expect(EloRankable.config.k_factor_for(2100)).to eq(20)
      expect(EloRankable.config.k_factor_for(2500)).to eq(10)
    end

    it 'allows custom k-factor strategy' do
      EloRankable.configure do |config|
        config.k_factor_for = ->(_rating) { 25 }
      end

      expect(EloRankable.config.k_factor_for(1000)).to eq(25)
      expect(EloRankable.config.k_factor_for(2500)).to eq(25)

      # Reset for other tests
      EloRankable.configure do |config|
        config.k_factor_for = lambda { |rating|
          if rating > 2400
            10
          elsif rating > 2000
            20
          else
            32
          end
        }
      end
    end
  end

  describe 'has_elo_ranking' do
    it 'initializes rating to base config value' do
      expect(player1.elo_rating).to eq(1200)
      expect(player1.games_played).to eq(0)
    end

    it 'creates elo_ranking association' do
      expect(player1.elo_ranking).to be_a(EloRankable::EloRanking)
      expect(player1.elo_ranking.rankable).to eq(player1)
    end
  end

  describe '1v1 matches' do
    it 'updates ratings correctly when player1 beats player2' do
      initial_rating1 = player1.elo_rating
      initial_rating2 = player2.elo_rating

      player1.beat!(player2)

      expect(player1.elo_rating).to be > initial_rating1
      expect(player2.elo_rating).to be < initial_rating2
      expect(player1.games_played).to eq(1)
      expect(player2.games_played).to eq(1)
    end

    it 'updates ratings correctly when player2 beats player1 using lost_to!' do
      initial_rating1 = player1.elo_rating
      initial_rating2 = player2.elo_rating

      player1.lost_to!(player2)

      expect(player1.elo_rating).to be < initial_rating1
      expect(player2.elo_rating).to be > initial_rating2
      expect(player1.games_played).to eq(1)
      expect(player2.games_played).to eq(1)
    end

    it 'handles draws correctly' do
      initial_rating1 = player1.elo_rating
      initial_rating2 = player2.elo_rating

      player1.draw_with!(player2)

      # For equal ratings, draw should not change ratings much
      expect((player1.elo_rating - initial_rating1).abs).to be < 5
      expect((player2.elo_rating - initial_rating2).abs).to be < 5
      expect(player1.games_played).to eq(1)
      expect(player2.games_played).to eq(1)
    end
  end

  describe 'multiplayer matches' do
    it 'updates all pairwise outcomes correctly' do
      [player1.elo_rating, player2.elo_rating, player3.elo_rating]

      EloRankable.record_multiplayer_match([player1, player2, player3])

      # Player1 should have highest rating (beat both others)
      # Player2 should have middle rating (beat player3, lost to player1)
      # Player3 should have lowest rating (lost to both others)
      expect(player1.elo_rating).to be > player2.elo_rating
      expect(player2.elo_rating).to be > player3.elo_rating

      # All should have played 2 games (against each other player once)
      expect(player1.games_played).to eq(2)
      expect(player2.games_played).to eq(2)
      expect(player3.games_played).to eq(2)
    end

    it 'raises error for fewer than 2 players' do
      expect do
        EloRankable.record_multiplayer_match([player1])
      end.to raise_error(EloRankable::InvalidMatchError, 'Need at least 2 players for a match')
    end
  end

  describe 'single winner matches' do
    it 'updates winner and all losers correctly' do
      initial_rating1 = player1.elo_rating
      initial_rating2 = player2.elo_rating
      initial_rating3 = player3.elo_rating

      EloRankable.record_winner_vs_all(player1, [player2, player3])

      # Winner should gain rating
      expect(player1.elo_rating).to be > initial_rating1

      # Losers should lose rating
      expect(player2.elo_rating).to be < initial_rating2
      expect(player3.elo_rating).to be < initial_rating3

      # Winner plays against each loser
      expect(player1.games_played).to eq(2)
      # Each loser plays only against winner
      expect(player2.games_played).to eq(1)
      expect(player3.games_played).to eq(1)
    end

    it 'raises error for empty losers list' do
      expect do
        EloRankable.record_winner_vs_all(player1, [])
      end.to raise_error(EloRankable::InvalidMatchError, 'Need at least 1 loser')
    end

    it 'raises error when winner is in losers list' do
      expect do
        EloRankable.record_winner_vs_all(player1, [player1, player2])
      end.to raise_error(EloRankable::InvalidMatchError, 'Winner cannot be in losers list')
    end
  end

  describe 'leaderboards and scopes' do
    before do
      # Set up some ratings
      player1.elo_ranking.update!(rating: 1500)
      player2.elo_ranking.update!(rating: 1300)
      player3.elo_ranking.update!(rating: 1400)
    end

    it 'orders players by elo rating' do
      top_players = Player.by_elo_rating
      expect(top_players.first).to eq(player1)
      expect(top_players.second).to eq(player3)
      expect(top_players.third).to eq(player2)
    end

    it 'limits top rated players' do
      top_2 = Player.top_rated(2)
      expect(top_2.count).to eq(2)
      expect(top_2.first).to eq(player1)
      expect(top_2.second).to eq(player3)
    end
  end

  describe 'method aliases' do
    it 'provides elo_ prefixed aliases' do
      initial_rating1 = player1.elo_rating
      initial_rating2 = player2.elo_rating

      player1.elo_beat!(player2)

      expect(player1.elo_rating).to be > initial_rating1
      expect(player2.elo_rating).to be < initial_rating2
    end
  end

  describe 'polymorphic support' do
    let(:team1) { Team.create!(name: 'Team Alpha') }
    let(:team2) { Team.create!(name: 'Team Beta') }

    it 'works with different model types' do
      expect(team1.elo_rating).to eq(1200)

      team1.beat!(team2)

      expect(team1.elo_rating).to be > 1200
      expect(team2.elo_rating).to be < 1200
    end
  end

  describe 'performance' do
    it 'leaderboard queries complete in reasonable time' do
      # Create more players to test performance and trigger elo_ranking creation
      players = 50.times.map { |i| Player.create!(name: "Player #{i}") }
      
      # Trigger elo_ranking creation for each player
      players.each(&:elo_rating)

      start_time = Time.current
      top_players = Player.by_elo_rating.limit(10).to_a
      end_time = Time.current

      expect(top_players.size).to eq(10)
      expect(end_time - start_time).to be < 1.0  # Should complete in under 1 second
    end

    it 'accessing elo_rating does not reload association unnecessarily' do
      player = Player.create!(name: "Test Player")

      # First access creates the ranking
      first_ranking = player.elo_ranking

      # Subsequent accesses should return the same object
      second_ranking = player.elo_ranking

      expect(first_ranking.object_id).to eq(second_ranking.object_id)
    end

    it 'leaderboard queries perform well' do
      # Create players and ensure they have elo_rankings
      players = 10.times.map { |i| Player.create!(name: "Player #{i}") }
      players.each(&:elo_rating)  # Trigger elo_ranking creation

      expect {
        Player.by_elo_rating.limit(5).map(&:elo_rating)
      }.to perform_under(100).ms
    end
  end
end
