# frozen_string_literal: true

module EloRankable
  class Configuration
    attr_accessor :base_rating
    attr_reader :k_factor_strategy

    def initialize
      @base_rating = 1200
      @k_factor_strategy = default_k_factor_strategy
    end

    def k_factor_for=(strategy)
      @k_factor_strategy = strategy
    end

    def k_factor_for(rating)
      case @k_factor_strategy
      when Proc
        @k_factor_strategy.call(rating)
      when Numeric
        @k_factor_strategy
      else
        raise ArgumentError, 'K-factor strategy must be a Proc or Numeric'
      end
    end

    private

    def default_k_factor_strategy
      lambda do |rating|
        if rating > 2400
          10
        elsif rating > 2000
          20
        else
          32
        end
      end
    end
  end
end
