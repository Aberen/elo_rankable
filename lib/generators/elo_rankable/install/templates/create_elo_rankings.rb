# frozen_string_literal: true

class CreateEloRankings < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :elo_rankings do |t|
      t.references :rankable, polymorphic: true, null: false, index: true
      t.integer :rating, null: false, default: 1200
      t.integer :games_played, null: false, default: 0

      t.timestamps
    end

    add_index :elo_rankings, :rating
    add_index :elo_rankings, %i[rankable_type rankable_id], unique: true
  end
end
