require 'test_helper'

class Player
  include MongoMapper::EmbeddedDocument

  key :name, String
end

class Team
  include MongoMapper::Document

  key :captain, Player

  many :players
  many :retired_players, :class => Player
  
  many :games
end

class Game
  include MongoMapper::Document

  key :opponent, String
  key :team_id

  belongs_to :team
end


class NestedAttributesTest < Test::Unit::TestCase
  def setup
    Team.collection.remove
  end

  context "Passing nested attributes" do
    setup do
      Team.accepts_nested_attributes_for(:players, :games, :retired_players, :captain, :allow_destroy => true)
      @team = Team.create(:name => 'Nesting Attributes',
                          :captain_attributes => {:name => 'Special guy'},
                          :players_attributes => [{:name => 'Normal guy'}],
                          :retired_players_attributes => [{:name => 'Old guy'}],
                          :games_attributes => [{:opponent => 'Other team'}]
                          )
    end

    should "work for embedded documents" do
      @team.captain.name.should == 'Special guy'
    end

    should "work for embedded collections" do
      @team.players.size.should == 1
      @team.players.first.name.should == 'Normal guy'
    end

    should "work for associated documents" do
      @team.games.size.should == 1
      @team.games.first.opponent.should == 'Other team'
    end

    should "work with custom class names" do
      @team.retired_players.size.should == 1
      @team.retired_players.first.name.should == 'Old guy'
    end

    context "with _destroy => true" do
      context "when destruction is allowed" do
        setup do
          assign_attributes_to_delete_associated_documents
        end

        should_eventually "not destroy associated documents until the document is saved" do
          @team.games.size.should == 1
        end

        should "destroy embedded documents when saved" do
          @team.save
          @team.captain.should be_nil
        end

        should "destroy documents in embedded collections when saved" do
          @team.save
          @team.players.size.should == 0
        end

        should "destroy associated documents when saved" do
          @team.save
          @team.games.size.should == 0
        end
      end

      context "when destruction is not allowed" do
        should "not destroy nested documents" do
          Team.accepts_nested_attributes_for(:players, :games, :captain, :allow_destroy => false)
          assign_attributes_to_delete_associated_documents
          @team.save
          @team.captain.name.should == 'Special guy'
          @team.players.size.should == 1
          @team.games.size.should == 1
        end
      end
    end


  end

  should "raise an ArgumentError for non existing associations" do
    lambda {
      Team.accepts_nested_attributes_for :blah
    }.should raise_error(ArgumentError)
  end

  def assign_attributes_to_delete_associated_documents
    captain = @team.captain.attributes.merge({:_destroy => true})
    player  = @team.players.first.attributes.merge({:_destroy => true})
    game    = @team.games.first.attributes.merge({:_destroy => true})

    @team.attributes = {:players_attributes => [player], :games_attributes => [game], :captain_attributes => captain}
  end

end
