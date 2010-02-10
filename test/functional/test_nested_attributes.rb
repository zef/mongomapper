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
  one :coach
end

class Game
  include MongoMapper::Document

  key :opponent, String
  key :team_id, ObjectId

  belongs_to :team
end

class Coach
  include MongoMapper::Document

  key :team_id
end


class NestedAttributesTest < Test::Unit::TestCase
  def setup
    Team.collection.remove
  end

  context "Passing nested attributes" do
    setup do
      Team.accepts_nested_attributes_for(:players, :games, :retired_players, :captain, :coach, :allow_destroy => true)
      @team = Team.create(:name => 'Nested Attributes',
                          :captain_attributes => {:name => 'Special guy'},
                          :players_attributes => [{:name => 'Normal guy'}],
                          :retired_players_attributes => [{:name => 'Old guy'}],
                          :coach_attributes => {:name => 'Experienced guy'},
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

    should "work for associated collections" do
      @team.games.size.should == 1
      @team.games.first.opponent.should == 'Other team'
    end

    should "work for associated 'one' documents" do
      @team.coach.team_id.should == @team.id
    end

    should "work with custom class names" do
      @team.retired_players.size.should == 1
      @team.retired_players.first.name.should == 'Old guy'
    end

    context "to update existing records" do
      setup do

      end

      context "with :_destroy => true" do
        context "when destruction is allowed" do
          setup do
            assign_attributes_to_delete_associated_documents
          end

          should_eventually "not destroy documents in associated collections before root document is saved" do
            @team.reload
            @team.games.size.should == 1
          end

          should_eventually "not destroy associated 'one' documents before root document is saved" do
            @team.reload
            @team.coach.name.should == 'Experienced guy'
          end

          should "destroy associated 'one' documents when saved" do
            @team.save
            @team.reload
            @team.coach.class.should_not == Coach
          end

          should "destroy embedded documents when saved" do
            @team.save
            @team.captain.should be_nil
          end

          should "destroy documents in embedded collections when saved" do
            @team.save
            @team.players.size.should == 0
          end

          should "destroy documents in associated collections when saved" do
            @team.save
            @team.reload
            @team.games.size.should == 0
          end
        end

       context "when destruction is not allowed" do
         should "not destroy nested documents" do
           Team.accepts_nested_attributes_for(:players, :games, :captain, :coach, :allow_destroy => false)
           assign_attributes_to_delete_associated_documents
           @team.save
           @team.reload
           @team.coach.name.should == 'Experienced guy'
           @team.captain.name.should == 'Special guy'
           @team.players.size.should == 1
           @team.games.size.should == 1
         end
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
    player  = @team.players.first.attributes.merge({:_destroy => true})
    game    = @team.games.first.attributes.merge({:_destroy => true})
    captain = @team.captain.attributes.merge({:_destroy => true})
    coach   = @team.coach.attributes.merge({:_destroy => true})

    @team.attributes = {:players_attributes => [player], :games_attributes => [game], :captain_attributes => captain, :coach_attributes => coach}
  end

end
