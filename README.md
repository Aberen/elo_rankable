# elo_rankable

A Ruby gem that adds Elo rating capabilities to any ActiveRecord model using a simple `has_elo_ranking` declaration. It stores ratings in a separate `EloRanking` model to keep your host model clean, and provides domain-style methods for updating rankings after matches.

## Features

- 🎯 **Simple Integration**: Add Elo rankings to any ActiveRecord model with one line
- 🏆 **Multiple Match Types**: Support for 1v1, draws, multiplayer (ranked), and winner-vs-all matches
- ⚙️ **Configurable**: Customizable base rating and K-factor strategies
- 📊 **Leaderboards**: Built-in scopes for rankings and top players
- 🧹 **Clean Design**: Ratings stored separately from your main models
- 🔄 **Polymorphic**: Works with any ActiveRecord model (User, Player, Team, etc.)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'elo_rankable'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install elo_rankable
```

## Setup

### 1. Generate and run the migration

```bash
$ rails generate elo_rankable:install
$ rails db:migrate
```

### 2. Add to your models

```ruby
class Player < ApplicationRecord
  has_elo_ranking
end

class Team < ApplicationRecord
  has_elo_ranking
end
```

## Usage

### Basic 1v1 Matches

```ruby
alice = Player.create!(name: "Alice")
bob = Player.create!(name: "Bob")

# Both players start with the default rating (1200)
alice.elo_rating  # => 1200
bob.elo_rating    # => 1200

# Record a match where Alice beats Bob
alice.beat!(bob)

alice.elo_rating  # => 1216
bob.elo_rating    # => 1184

# Alternative syntax
bob.lost_to!(alice)  # Same effect as alice.beat!(bob)

# Record a draw
alice.draw_with!(bob)

alice.elo_rating  # => 1200 (no change for equal ratings)
bob.elo_rating    # => 1200 (no change for equal ratings)

# Example with different ratings
charlie = Player.create!(name: "Charlie")
charlie.elo_ranking.update!(rating: 1400)  # Charlie is higher rated

charlie.draw_with!(alice)  # Draw between 1400 vs 1200

charlie.elo_rating  # => 1392 (lost 8 points - draw hurts higher rated player)
alice.elo_rating    # => 1208 (gained 8 points - draw helps lower rated player)
```

### Multiplayer Matches (Ranked)

For tournaments or matches where players finish in ranked order:

```ruby
players = [first_place, second_place, third_place, fourth_place]

# Higher-indexed players are treated as having lost to lower-indexed ones
EloRankable.record_multiplayer_match(players)

# This is equivalent to:
# first_place.beat!(second_place)
# first_place.beat!(third_place)
# first_place.beat!(fourth_place)
# second_place.beat!(third_place)
# second_place.beat!(fourth_place)
# third_place.beat!(fourth_place)
```

### Winner vs All Matches

For matches where one player/team beats everyone else, but the losers don't compete against each other:

```ruby
winner = Player.find_by(name: "Champion")
losers = [player1, player2, player3]

EloRankable.record_winner_vs_all(winner, losers)

# Winner gains rating by beating each loser individually
# Losers only lose rating to the winner, not to each other
```

### Global Draw Recording

```ruby
EloRankable.record_draw(player1, player2)
```

### Accessing Rating Information

```ruby
player = Player.first

player.elo_rating      # Current Elo rating
player.games_played    # Number of games played
player.elo_ranking     # Access to the full EloRanking record
```

### Accessing K-Factor Values

```ruby
# Get the K-factor for a specific rating
EloRankable.config.k_factor_for(1500)  # => 32
EloRankable.config.k_factor_for(2200)  # => 20
```

### Leaderboards and Scopes

```ruby
# Get players ordered by rating (highest first)
top_players = Player.by_elo_rating

# Get top 10 players
top_10 = Player.top_rated(10)

# Access EloRanking records directly
top_ratings = EloRankable::EloRanking.by_rating.limit(10)
```

## Configuration

### Base Rating

```ruby
EloRankable.configure do |config|
  config.base_rating = 1500  # Default is 1200
end
```

### K-Factor Strategy

The K-factor determines how much ratings change after each match. You can use a constant value or a dynamic strategy based on rating:

#### Constant K-Factor

```ruby
EloRankable.configure do |config|
  config.k_factor_for = 32
end
```

#### Dynamic K-Factor (Default)

```ruby
EloRankable.configure do |config|
  config.k_factor_for = ->(rating) do
    if rating > 2400
      10   # Masters: smaller changes
    elsif rating > 2000
      20   # Experts: medium changes  
    else
      32   # Beginners: larger changes
    end
  end
end
```

## Method Reference

### Instance Methods (added by `has_elo_ranking`)

| Method | Description |
|--------|-------------|
| `beat!(other)` | Record a win against another player |
| `lost_to!(other)` | Record a loss to another player |
| `draw_with!(other)` | Record a draw with another player |
| `elo_beat!(other)` | Alias for `beat!` |
| `elo_lost_to!(other)` | Alias for `lost_to!` |
| `elo_draw_with!(other)` | Alias for `draw_with!` |
| `elo_rating` | Current Elo rating |
| `games_played` | Number of games played |
| `elo_ranking` | Associated EloRanking record |

### Class Methods (added by `has_elo_ranking`)

| Scope | Description |
|-------|-------------|
| `by_elo_rating` | Order by Elo rating (highest first) |
| `top_rated(limit)` | Get top N players by rating |

### Module Methods

| Method | Description |
|--------|-------------|
| `EloRankable.record_multiplayer_match(players)` | Record ranked multiplayer match |
| `EloRankable.record_winner_vs_all(winner, losers)` | Record winner-takes-all match |
| `EloRankable.record_draw(player1, player2)` | Record a draw |

## How Elo Rating Works

The Elo rating system calculates expected outcomes based on rating differences and adjusts ratings based on actual results:

- **Expected Score**: Higher-rated players are expected to win more often
- **Rating Change**: Beating a higher-rated opponent gives more points than beating a lower-rated one
- **K-Factor**: Controls how much ratings can change (higher K = more volatile)

### Example Calculation

```ruby
# Alice (1200) vs Bob (1200) - equal ratings
alice.beat!(bob)
# Alice: 1200 + 16 = 1216 (gained 16 points)
# Bob:   1200 - 16 = 1184 (lost 16 points)

# Alice (1400) vs Charlie (1200) - Alice favored
alice.beat!(charlie)
# Alice: 1400 + 11 = 1411 (gained 11 points - expected to win)
# Charlie: 1200 - 11 = 1189 (lost 11 points)

# Charlie (1189) beats Alice (1411) - upset!
charlie.beat!(alice)
# Charlie: 1189 + 21 = 1210 (gained 21 points - major upset)
# Alice: 1411 - 21 = 1390 (lost 21 points)
```


## Error Handling

The gem provides comprehensive validation with specific error types:

### EloRankable::InvalidMatchError
- Thrown when match requirements aren't met (e.g., less than 2 players)
- Winner appears in losers list

### ArgumentError
- Nil players/opponents
- Duplicate players in arrays
- Players that don't respond to `elo_ranking`
- Playing against yourself or destroyed records

```ruby
# Examples that will raise errors:
alice.beat!(nil)                    # ArgumentError: Cannot play against nil
alice.beat!(alice)                  # ArgumentError: Cannot play against yourself
EloRankable.record_multiplayer_match([alice])  # InvalidMatchError: Need at least 2 players
```


## Database Schema

The gem creates an `elo_rankings` table:

```ruby
create_table :elo_rankings do |t|
  t.references :rankable, polymorphic: true, null: false, index: true
  t.integer :rating, null: false, default: 1200
  t.integer :games_played, null: false, default: 0
  t.timestamps
end

add_index :elo_rankings, :rating
add_index :elo_rankings, [:rankable_type, :rankable_id], unique: true
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/aberen/elo_rankable.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).