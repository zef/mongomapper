require 'test_helper'

class IdentityMapTest < Test::Unit::TestCase
  def assert_in_map(resource)
    resource.identity_map.keys.should include(resource.identity_map_key)
    mapped_resource = resource.identity_map[resource.identity_map_key]
    resource.object_id.should == mapped_resource.object_id
  end
  
  def assert_not_in_map(resource)
    resource.identity_map.keys.should_not include(resource.identity_map_key)
  end
  
  context "Document" do
    setup do
      @person_class = Doc('Person') do
        key :name, String
        plugin MongoMapper::Plugins::IdentityMap
      end
      
      @post_class = Doc('Post') do
        key :title, String
        plugin MongoMapper::Plugins::IdentityMap
      end
      
      @person_class.identity_map = {}
      @post_class.identity_map   = {}
    end

    should "default identity map to hash" do
      Doc() do
        plugin MongoMapper::Plugins::IdentityMap
      end.identity_map.should == {}
    end

    should "share identity map with other classes" do
      map = @post_class.identity_map
      map.object_id.should == @person_class.identity_map.object_id
    end

    should "have identity map key that is always unique per document and class" do
      person = @person_class.new
      person.identity_map_key.should == "Person:#{person.id}"
      @person_class.identity_map_key(person.id).should == person.identity_map_key

      post = @post_class.new
      post.identity_map_key.should == "Post:#{post.id}"
      @post_class.identity_map_key(post.id).should == post.identity_map_key

      person.identity_map_key.should_not == post.identity_map_key
    end

    should "add key to map when saved" do
      person = @person_class.new
      assert_not_in_map(person)
      person.save.should be_true
      assert_in_map(person)
    end

    should "remove key from map when deleted" do
      person = @person_class.create(:name => 'Fred')
      assert_in_map(person)
      person.destroy
      assert_not_in_map(person)
    end
    
    context "#load" do
      setup do
        @id = Mongo::ObjectID.new
      end
      
      should "add document to map with _id key as symbol" do
        loaded = @person_class.load({:_id => @id, :name => 'Frank'})
        assert_in_map(loaded)
      end
      
      should "add document to map with _id key as string" do
        loaded = @person_class.load({'_id' => @id, :name => 'Frank'})
        assert_in_map(loaded)
      end
      
      should "add document to map with id key as symbol" do
        loaded = @person_class.load({:id => @id, :name => 'Frank'})
        assert_in_map(loaded)
      end
      
      should "add document to map with id key as string" do
        loaded = @person_class.load({'id' => @id, :name => 'Frank'})
        assert_in_map(loaded)
      end
      
      should "return document if already in map" do
        first_load = @person_class.load({:_id => @id, :name => 'Frank'})
        @person_class.identity_map.expects(:[]=).never
        second_load = @person_class.load({:_id => @id, :name => 'Frank'})
        first_load.object_id.should == second_load.object_id
      end
    end
    
    context "#find (with one id)" do
      context "for object not in map" do
        setup do
          @person = @person_class.create(:name => 'Fred')
          @person_class.identity_map.clear
        end

        should "query the database" do
          Mongo::Collection.any_instance.expects(:find_one).once
          @person_class.find(@person.id)
        end

        should "add object to map" do
          assert_not_in_map(@person)
          found_person = @person_class.find(@person.id)
          assert_in_map(found_person)
        end
      end

      context "for object in map" do
        setup do
          @person = @person_class.create(:name => 'Fred')
        end

        should "not query database" do
          Mongo::Collection.any_instance.expects(:find).never
          Mongo::Collection.any_instance.expects(:find_one).never
          @person_class.find(@person.id)
        end
        
        should "return exact object" do
          assert_in_map(@person)
          found_person = @person_class.find(@person.id)
          found_person.object_id.should == @person.object_id
        end
      end
    end
    
    context "#find (with multiple ids)" do
      should "add all documents to map" do
        person1 = @person_class.create(:name => 'Fred')
        person2 = @person_class.create(:name => 'Bill')
        person3 = @person_class.create(:name => 'Jesse')
        @person_class.identity_map.clear

        people = @person_class.find(person1.id, person2.id, person3.id)
        people.each { |person| assert_in_map(person) }
      end

      should "add missing documents to map and return existing ones" do
        person1 = @person_class.create(:name => 'Fred')
        @person_class.identity_map.clear
        person2 = @person_class.create(:name => 'Bill')
        person3 = @person_class.create(:name => 'Jesse')

        assert_not_in_map(person1)
        assert_in_map(person2)
        assert_in_map(person3)

        people = @person_class.find(person1.id, person2.id, person3.id)
        assert_in_map(people.first) # making sure one that wasn't mapped now is
        assert_in_map(person2)
        assert_in_map(person3)
      end
    end
    
    context "#first" do
      context "for object not in map" do
        setup do
          @person = @person_class.create(:name => 'Fred')
          @person_class.identity_map.clear
        end

        should "query the database" do
          Mongo::Collection.any_instance.expects(:find_one).once
          @person_class.first(:_id => @person.id)
        end

        should "add object to map" do
          assert_not_in_map(@person)
          found_person = @person_class.first(:_id => @person.id)
          assert_in_map(found_person)
        end
      end

      context "for object in map" do
        setup do
          @person = @person_class.create(:name => 'Fred')
        end

        should "not query database" do
          Mongo::Collection.any_instance.expects(:find).never
          Mongo::Collection.any_instance.expects(:find_one).never
          @person_class.first(:_id => @person.id)
        end
        
        should "return exact object" do
          assert_in_map(@person)
          found_person = @person_class.first(:_id => @person.id)
          found_person.object_id.should == @person.object_id
        end
      end
    end
    
    context "#all" do
      should "add all documents to map" do
        person1 = @person_class.create(:name => 'Fred')
        person2 = @person_class.create(:name => 'Bill')
        person3 = @person_class.create(:name => 'Jesse')
        @person_class.identity_map.clear

        people = @person_class.all(:_id => [person1.id, person2.id, person3.id])
        people.each { |person| assert_in_map(person) }
      end

      should "add missing documents to map and return existing ones" do
        person1 = @person_class.create(:name => 'Fred')
        @person_class.identity_map.clear
        person2 = @person_class.create(:name => 'Bill')
        person3 = @person_class.create(:name => 'Jesse')

        assert_not_in_map(person1)
        assert_in_map(person2)
        assert_in_map(person3)

        people = @person_class.all(:_id => [person1.id, person2.id, person3.id])
        assert_in_map(people.first) # making sure one that wasn't mapped now is
        assert_in_map(person2)
        assert_in_map(person3)
      end
    end
    
  end
end