require 'test_helper'
require 'models'

class NestedAttributesTest < Test::Unit::TestCase
  def setup
    Project.accepts_nested_attributes_for(:people, :collaborators)
    Project.collection.remove
  end

  context "A Document" do
    setup do
      @project = Project.create(:name => 'Nesting Attributes',
                                :people_attributes => [{:name => 'Zef'}],
                                :collaborators_attributes => [{:name => 'Zef'}]
                                )
    end

    should "accept nested attributes for embedded documents" do
      # puts @project.attributes.inspect
      # puts @project.people.inspect
      # puts @project.collaborators.inspect
      @project.people.size.should == 1
    end
    should "accept nested attributes for associated documents" do
      @project.collaborators.size.should == 1
    end
    
    context "which already exists" do
      setup do
        person       = @project.people.first.attributes.merge({:_destroy => true})
        collaborator = @project.collaborators.first.attributes.merge({:_destroy => true})
        puts @project.collaborators.inspect
        
        # @project.update_attributes(:people_attributes => [person], :collaborators_attributes => [collaborator])
        @project.attributes = {:people_attributes => [person], :collaborators_attributes => [collaborator]}
        puts @project.collaborators.inspect
        # @project.save
        puts @project.collaborators.inspect
      end

      should "not destroy associated documents until the document is saved" do
        @project.collaborators.size.should == 1
      end
      
      should "destroy embedded documents when saved" do
        @project.save
        @project.reload
        @project.people.size.should == 0
      end

      should "destroy associated documents when saved" do
        @project.save
        @project.reload
        @project.collaborators.size.should == 0
      end      
    end

  end

  should "raise an ArgumentError for non existing associations" do
    lambda {
      Project.accepts_nested_attributes_for :blah
    }.should raise_error(ArgumentError)
  end


end