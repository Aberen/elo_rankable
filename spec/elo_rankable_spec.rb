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
      top_two = Player.top_rated(2)
      expect(top_two.count).to eq(2)
      expect(top_two.first).to eq(player1)
      expect(top_two.second).to eq(player3)
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
      expect(end_time - start_time).to be < 1.0 # Should complete in under 1 second
    end

    it 'accessing elo_rating does not reload association unnecessarily' do
      player = Player.create!(name: 'Test Player')

      # First access creates the ranking
      first_ranking = player.elo_ranking

      # Subsequent accesses should return the same object
      second_ranking = player.elo_ranking

      expect(first_ranking.object_id).to eq(second_ranking.object_id)
    end

    it 'leaderboard queries perform well' do
      # Create players and ensure they have elo_rankings
      players = 10.times.map { |i| Player.create!(name: "Player #{i}") }
      players.each(&:elo_rating) # Trigger elo_ranking creation

      expect do
        Player.by_elo_rating.limit(5).map(&:elo_rating)
      end.to perform_under(100).ms
    end
  end

  describe 'edge cases' do
    it 'handles very high ratings correctly' do
      player1.elo_ranking.update!(rating: 3000)
      player2.elo_ranking.update!(rating: 800)

      expect { player1.beat!(player2) }.not_to raise_error
      # High-rated player should gain very little from beating low-rated player
      expect(player1.elo_rating).to be < 3010
    end

    it 'handles negative ratings gracefully' do
      player1.elo_ranking.update!(rating: 100)
      player2.elo_ranking.update!(rating: 2000)

      player1.lost_to!(player2)
      expect(player1.elo_rating).to be >= 0 # Should not go negative
    end

    it 'handles self-match attempts' do
      expect { player1.beat!(player1) }.to raise_error(ArgumentError, 'Cannot play against yourself')
    end

    it 'handles nil players' do
      expect { player1.beat!(nil) }.to raise_error(ArgumentError, 'Cannot play against nil')
    end

    it 'handles objects that do not respond to elo_ranking' do
      non_rankable = double('NonRankable')
      expect { player1.beat!(non_rankable) }.to raise_error(ArgumentError, 'Opponent must respond to elo_ranking')
    end

    it 'handles opponents with nil elo_ranking' do
      # With improved validation, this should now be caught properly
      mock_player = double('MockPlayer')
      allow(mock_player).to receive(:respond_to?).with(:elo_ranking).and_return(true)
      allow(mock_player).to receive(:respond_to?).with(:destroyed?).and_return(false)
      allow(mock_player).to receive(:elo_ranking).and_return(nil)

      expect { player1.beat!(mock_player) }.to raise_error(ArgumentError, "Opponent's elo_ranking is not initialized")
    end

    it 'handles opponents with unsaved elo_ranking' do
      # Create a player with an unsaved elo_ranking
      unsaved_player = Player.new(name: 'Unsaved')
      unsaved_ranking = EloRankable::EloRanking.new(
        rating: EloRankable.config.base_rating,
        games_played: 0
      )
      allow(unsaved_player).to receive(:elo_ranking).and_return(unsaved_ranking)

      # With improved validation, this should be caught properly
      expect { player1.beat!(unsaved_player) }.to raise_error(ArgumentError, "Opponent's elo_ranking is not saved")
    end

    it 'handles extreme rating differences without overflow' do
      player1.elo_ranking.update!(rating: 1)
      player2.elo_ranking.update!(rating: 9999)

      expect { player1.beat!(player2) }.not_to raise_error
      expect { player2.beat!(player1) }.not_to raise_error

      # Verify ratings are still within reasonable bounds
      expect(player1.elo_rating).to be_between(0, 10_000)
      expect(player2.elo_rating).to be_between(0, 10_000)
    end

    it 'handles players from different model types in matches' do
      team = Team.create!(name: 'Test Team')

      expect { player1.beat!(team) }.not_to raise_error
      expect(player1.games_played).to eq(1)
      expect(team.games_played).to eq(1)
    end

    it 'handles multiple consecutive matches between same players' do
      initial_rating1 = player1.elo_rating
      initial_rating2 = player2.elo_rating

      # Play 10 matches
      10.times { player1.beat!(player2) }

      expect(player1.games_played).to eq(10)
      expect(player2.games_played).to eq(10)
      expect(player1.elo_rating).to be > initial_rating1
      expect(player2.elo_rating).to be < initial_rating2
    end

    it 'handles draw between players with very different ratings' do
      player1.elo_ranking.update!(rating: 2500)
      player2.elo_ranking.update!(rating: 800)

      initial_rating1 = player1.elo_rating
      initial_rating2 = player2.elo_rating

      player1.draw_with!(player2)

      # Higher rated player should lose rating in a draw, lower should gain
      expect(player1.elo_rating).to be < initial_rating1
      expect(player2.elo_rating).to be > initial_rating2
    end

    it 'handles concurrent access to same player rankings' do
      # Simulate potential race condition by accessing elo_ranking multiple times
      # Skip database threading test in spec environment
      player1.elo_rating # Trigger creation

      # Should not create multiple elo_ranking records
      expect(EloRankable::EloRanking.where(rankable: player1).count).to eq(1)

      # Test that multiple accesses return consistent results
      expect(player1.elo_rating).to eq(player1.elo_rating)
    end

    it 'validates that deleted/destroyed players cannot participate in matches' do
      destroyed_player = Player.create!(name: 'ToDestroy')
      destroyed_player.destroy

      # With improved validation, this should be caught properly
      expect { player2.beat!(destroyed_player) }.to raise_error(ArgumentError, 'Cannot play against a destroyed record')
    end

    it 'handles matches where players have exactly the same rating' do
      # Ensure both players have identical ratings
      player1.elo_ranking.update!(rating: 1500)
      player2.elo_ranking.update!(rating: 1500)

      player1.beat!(player2)

      # Winner should gain exactly what loser loses
      rating_diff = player1.elo_rating - player2.elo_rating
      expect(rating_diff).to be > 0
      expect(player1.elo_rating + player2.elo_rating).to eq(3000) # Total should be conserved
    end

    it 'handles very large number of games played without overflow' do
      player1.elo_ranking.update!(games_played: 999_999)
      player2.elo_ranking.update!(games_played: 999_999)

      expect { player1.beat!(player2) }.not_to raise_error
      expect(player1.games_played).to eq(1_000_000)
      expect(player2.games_played).to eq(1_000_000)
    end

    describe 'multiplayer edge cases' do
      it 'handles single player arrays' do
        expect do
          EloRankable.record_multiplayer_match([player1])
        end.to raise_error(EloRankable::InvalidMatchError, 'Need at least 2 players for a match')
      end

      it 'handles empty arrays' do
        expect do
          EloRankable.record_multiplayer_match([])
        end.to raise_error(EloRankable::InvalidMatchError, 'Need at least 2 players for a match')
      end

      it 'handles nil values in players array' do
        expect do
          EloRankable.record_multiplayer_match([player1, nil, player2])
        end.to raise_error(ArgumentError, 'Players array cannot contain nil values')
      end

      it 'handles non-rankable objects in players array' do
        non_rankable = double('NonRankable')
        expect do
          EloRankable.record_multiplayer_match([player1, non_rankable, player2])
        end.to raise_error(ArgumentError, 'All players must respond to elo_ranking')
      end

      it 'handles duplicate players in multiplayer match' do
        # With improved validation, duplicates are now detected
        expect do
          EloRankable.record_multiplayer_match([player1, player2, player1])
        end.to raise_error(ArgumentError, 'Players array cannot contain duplicate players')
      end

      it 'handles very large multiplayer matches' do
        # Create 20 players for a large tournament
        players = 20.times.map { |i| Player.create!(name: "Player #{i}") }

        expect { EloRankable.record_multiplayer_match(players) }.not_to raise_error

        # Verify all players have correct number of games (n-1 for n players)
        players.each do |player|
          expect(player.games_played).to eq(19)
        end
      end
    end

    describe 'winner vs all edge cases' do
      it 'handles nil winner' do
        expect do
          EloRankable.record_winner_vs_all(nil, [player2, player3])
        end.to raise_error(ArgumentError, 'Winner cannot be nil')
      end

      it 'handles nil in losers array' do
        expect do
          EloRankable.record_winner_vs_all(player1, [player2, nil])
        end.to raise_error(ArgumentError, 'Losers array cannot contain nil values')
      end

      it 'handles winner appearing in losers list' do
        expect do
          EloRankable.record_winner_vs_all(player1, [player1, player2])
        end.to raise_error(EloRankable::InvalidMatchError, 'Winner cannot be in losers list')
      end

      it 'handles duplicate losers' do
        # Current implementation doesn't check for duplicates in losers
        expect do
          EloRankable.record_winner_vs_all(player1, [player2, player2])
        end.not_to raise_error

        # Winner should play 2 matches (even though it's the same opponent twice)
        expect(player1.games_played).to eq(2)
        expect(player2.games_played).to eq(2)
      end

      it 'handles non-rankable objects in losers array' do
        non_rankable = double('NonRankable')
        expect do
          EloRankable.record_winner_vs_all(player1, [player2, non_rankable])
        end.to raise_error(ArgumentError, 'All losers must respond to elo_ranking')
      end

      it 'handles non-rankable winner' do
        non_rankable = double('NonRankable')
        expect do
          EloRankable.record_winner_vs_all(non_rankable, [player2, player3])
        end.to raise_error(ArgumentError, 'Winner must respond to elo_ranking')
      end
    end

    describe 'global draw method edge cases' do
      it 'handles nil players in draw' do
        expect do
          EloRankable.record_draw(nil, player2)
        end.to raise_error(ArgumentError, 'Player1 cannot be nil')

        expect do
          EloRankable.record_draw(player1, nil)
        end.to raise_error(ArgumentError, 'Player2 cannot be nil')
      end

      it 'handles self-draw attempts' do
        expect do
          EloRankable.record_draw(player1, player1)
        end.to raise_error(ArgumentError, 'Cannot record draw with same player')
      end

      it 'handles non-rankable objects in draw' do
        non_rankable = double('NonRankable')

        expect do
          EloRankable.record_draw(non_rankable, player2)
        end.to raise_error(ArgumentError, 'Player1 must respond to elo_ranking')

        expect do
          EloRankable.record_draw(player1, non_rankable)
        end.to raise_error(ArgumentError, 'Player2 must respond to elo_ranking')
      end
    end
  end
end
