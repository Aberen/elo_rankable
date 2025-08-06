# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive input validation for all public methods
- Early validation in `record_multiplayer_match` and `record_winner_vs_all` methods
- Validation for `record_draw` method
- Defensive validation in Calculator methods
- Detection of duplicate players in multiplayer matches
- Validation for nil values in player arrays
- Validation for non-rankable objects
- Validation for destroyed/deleted players

### Fixed
- **BREAKING**: Improved error handling with descriptive ArgumentError exceptions instead of NoMethodError or database constraint violations
- Fixed validation gaps where errors would bubble up from Calculator instead of being caught early
- Fixed race conditions in validation logic by caching `elo_ranking` calls
- Improved validation in `validate_opponent!` method to properly handle destroyed records

### Changed
- **BREAKING**: `record_multiplayer_match` now raises `ArgumentError` for duplicate players instead of allowing self-matches
- **BREAKING**: `record_winner_vs_all` now validates winner and losers arrays upfront
- **BREAKING**: `record_draw` now validates both players upfront
- All validation errors now provide clear, descriptive error messages

## [0.1.1] - 2025-08-07

### Fixed
- Added proper input validation to `beat!`, `lost_to!`, and `draw_with!` methods
- Fixed SQLite3 gem version compatibility with ActiveRecord 8.0

### Added
- Comprehensive edge case testing for high ratings, negative ratings, and invalid inputs
- Performance tests for leaderboard queries and association loading
- Input validation with descriptive error messages for nil players and self-matches

### Changed
- Improved error handling with ArgumentError exceptions for invalid match scenarios
- Enhanced test suite with better coverage of edge cases and error conditions

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
