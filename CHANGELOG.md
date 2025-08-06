# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-08-06

### Added
- Initial release
- `has_elo_ranking` macro for ActiveRecord models
- Support for 1v1 matches with `beat!`, `lost_to!`, and `draw_with!` methods
- Multiplayer ranked match support via `EloRankable.record_multiplayer_match`
- Winner-vs-all match support via `EloRankable.record_winner_vs_all`
- Configurable base rating and K-factor strategies
- Leaderboard scopes (`by_elo_rating`, `top_rated`)
- Polymorphic EloRanking model for clean separation
- Rails generator for database migration
- Comprehensive test suite
