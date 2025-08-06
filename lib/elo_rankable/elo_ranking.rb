# frozen_string_literal: true

module EloRankable
  class EloRanking < ActiveRecord::Base
    belongs_to :rankable, polymorphic: true

    validates :rating, presence: true, numericality: { greater_than: 0 }
    validates :games_played, presence: true, numericality: { greater_than_or_equal_to: 0 }

    scope :by_rating, -> { order(rating: :desc) }
    scope :top, ->(limit = 10) { by_rating.limit(limit) }

    def initialize(attributes = nil)
      super
      self.rating ||= EloRankable.config.base_rating
      self.games_played ||= 0
    end

    def k_factor
      EloRankable.config.k_factor_for(rating)
    end
  end
end
