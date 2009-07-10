share_examples_for 'A public Collection' do
  before :all do
    %w[ @article_model @article @other @original @articles @other_articles ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_defined?(ivar)
      raise "+#{ivar}+ should not be nil in before block" unless instance_variable_get(ivar)
    end

    @articles.loaded?.should == loaded
  end

  before :all do
    @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
               defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)

    @one_to_many  = @articles.kind_of?(DataMapper::Associations::OneToMany::Collection)
    @many_to_many = @articles.kind_of?(DataMapper::Associations::ManyToMany::Collection)

    @skip = @no_join && @many_to_many
  end

  before do
    pending if @skip
  end

  it { @articles.should respond_to(:<<) }

  describe '#<<' do
    before :all do
      @resource = @article_model.new(:title => 'Title')

      @return = @articles << @resource
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should append one Resource to the Collection' do
      @articles.last.should equal(@resource)
    end

    it 'should not relate the Resource to the Collection' do
      @resource.collection.should_not equal(@articles)
    end
  end

  it { @articles.should respond_to(:clear) }

  describe '#clear' do
    before :all do
      @resources = @articles.entries

      @return = @articles.clear
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should make the Collection empty' do
      @articles.should be_empty
    end

    it 'should orphan the Resources' do
      @resources.each { |resource| resource.collection.should_not equal(@articles) }
    end
  end

  [ :collect!, :map! ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.send(method) { |resource| @article_model.new(:title => 'Ignored Title', :content => 'New Content') }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should update the Collection inline' do
        @articles.each { |resource| resource.attributes.only(:title, :content).should == { :title => 'Sample Article', :content => 'New Content' } }
      end

      it 'should orphan each replaced Resource in the Collection' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end
  end

  it { @articles.should respond_to(:concat) }

  describe '#concat' do
    before :all do
      @return = @articles.concat(@other_articles)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should concatenate the two collections' do
      @return.should == [ @article, @other ]
    end

    it 'should relate each Resource to the Collection' do
      @other_articles.each { |resource| resource.collection.should equal(@articles) }
    end
  end

  [ :create, :create! ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      describe 'when scoped to a property' do
        before :all do
          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should use the query conditions to set default values' do
          @resource.title.should == 'Sample Article'
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end

      describe 'when scoped to the key' do
        before :all do
          @articles = @articles.all(:id => 1)

          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should not use the query conditions to set default values' do
          @resource.id.should_not == 1
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end

      describe 'when scoped to a property with multiple values' do
        before :all do
          @articles = @articles.all(:content => %w[ Sample Other ])

          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should not use the query conditions to set default values' do
          @resource.content.should be_nil
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end

      describe 'when scoped with a condition other than eql' do
        before :all do
          @articles = @articles.all(:content.not => 'Sample')

          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should not use the query conditions to set default values' do
          @resource.content.should be_nil
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end
    end
  end

  it { @articles.should respond_to(:delete) }

  describe '#delete' do
    describe 'with a Resource within the Collection' do
      before :all do
        @return = @resource = @articles.delete(@article)
      end

      it 'should return a DataMapper::Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the expected Resource' do
        # compare keys because FK attributes may have been altered
        # when removing from the Collection
        @resource.key.should == @article.key
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with a Resource not within the Collection' do
      before :all do
        @return = @articles.delete(@other)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it { @articles.should respond_to(:delete_at) }

  describe '#delete_at' do
    describe 'with an offset within the Collection' do
      before :all do
        @return = @resource = @articles.delete_at(0)
      end

      it 'should return a DataMapper::Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the expected Resource' do
        @resource.key.should == @article.key
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with an offset not within the Collection' do
      before :all do
        @return = @articles.delete_at(1)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it { @articles.should respond_to(:delete_if) }

  describe '#delete_if' do
    describe 'with a block that matches a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.delete_if { true }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'with a block that does not match a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.delete_if { false }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should not modify the Collection' do
        @articles.should == @resources
      end
    end
  end

  [ :destroy, :destroy! ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      describe 'on a normal collection' do
        before :all do
          @return = @articles.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should remove the Resources from the datasource' do
          @article_model.all(:title => 'Sample Article').should be_empty
        end

        it 'should clear the collection' do
          @articles.should be_empty
        end
      end

      describe 'on a limited collection' do
        before :all do
          @other   = @articles.create.freeze
          @limited = @articles.all(:limit => 1)

          @return = @limited.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should remove the Resources from the datasource' do
          @article_model.all(:title => 'Sample Article').should == [ @other ]
        end

        it 'should clear the collection' do
          @limited.should be_empty
        end

        it 'should not destroy the other Resource' do
          @article_model.get(*@other.key).should_not be_nil
        end
      end
    end
  end

  it { @articles.should respond_to(:insert) }

  describe '#insert' do
    before :all do
      @resources = @other_articles

      @return = @articles.insert(0, *@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should insert one or more Resources at a given offset' do
      @articles.should == @resources + [ @article ]
    end

    it 'should relate the Resources to the Collection' do
      @resources.each { |resource| resource.collection.should equal(@articles) }
    end
  end

  it { @articles.should respond_to(:inspect) }

  describe '#inspect' do
    before :all do
      @copy = @articles.dup
      @copy << @article_model.new(:title => 'Ignored Title', :content => 'Other Article')

      @return = @copy.inspect
    end

    it { @return.should match(/\A\[.*\]\z/) }

    it { @return.should match(/\bid=#{@article.id}\b/) }
    it { @return.should match(/\bid=nil\b/) }

    it { @return.should match(/\btitle=\"Sample Article\"\s/) }
    it { @return.should_not match(/\btitle=\"Ignored Title\"\s/) }
    it { @return.should match(/\bcontent=\"Other Article\"\s/) }
  end

  it 'should respond to a public model method with #method_missing' do
    @articles.should respond_to(:base_model)
  end

  it 'should respond to a belongs_to relationship method with #method_missing' do
    @articles.should respond_to(:original)
  end

  it 'should respond to a has n relationship method with #method_missing' do
    @articles.should respond_to(:revisions)
  end

  it 'should respond to a has 1 relationship method with #method_missing' do
    @articles.should respond_to(:previous)
  end

  describe '#method_missing' do
    describe 'with a public model method' do
      before :all do
        @return = @articles.base_model
      end

      should_not_be_a_kicker

      it 'should return expected object' do
        @return.should == @article_model
      end
    end

    describe 'with a belongs_to relationship method' do
      before :all do
        @return = @collection = @articles.originals
      end

      # FIXME: this is spec order dependent, move this into a helper method
      # and execute in the before :all block
      unless loaded
        it 'should not be a kicker' do
          pending do
            @articles.should_not be_loaded
          end
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return expected Collection' do
        @collection.should == [ @original ]
      end
    end

    describe 'with a has n relationship method' do
      before :all do
        @new = @articles.new

        # associate the article with children
        @article.revisions << @new
        @new.revisions     << @other

        @article.save
        @new.save
      end

      describe 'with no arguments' do
        before :all do
          @return = @collection = @articles.revisions
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          @collection.should == [ @other, @new ]
        end
      end

      describe 'with arguments' do
        before :all do
          @return = @collection = @articles.revisions(:fields => [ :id ])
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          @collection.should == [ @other, @new ]
        end

        { :id => true, :title => false, :content => false }.each do |attribute, expected|
          it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
            @collection.each { |resource| resource.attribute_loaded?(attribute).should == expected }
          end
        end
      end
    end

    describe 'with a has 1 relationship method' do
      before :all do
        @new = @articles.new

        @article.previous = @new
        @new.previous     = @other

        @article.save
        @new.save
      end

      describe 'with no arguments' do
        before :all do
          @return = @articles.previous
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          # association is sorted reverse by id
          @return.should == [ @new, @other ]
        end
      end

      describe 'with arguments' do
        before :all do
          @return = @articles.previous(:fields => [ :id ])
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          # association is sorted reverse by id
          @return.should == [ @new, @other ]
        end

        { :id => true, :title => false, :content => false }.each do |attribute, expected|
          it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
            @return.each { |resource| resource.attribute_loaded?(attribute).should == expected }
          end
        end
      end
    end

    describe 'with an unknown method' do
      it 'should raise an exception' do
        lambda {
          @articles.unknown
        }.should raise_error(NoMethodError)
      end
    end
  end

  it { @articles.should respond_to(:new) }

  describe '#new' do
    describe 'when scoped to a property' do
      before :all do
        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should use the query conditions to set default values' do
        @resource.title.should == 'Sample Article'
      end
    end

    describe 'when scoped to the key' do
      before :all do
        @articles = @articles.all(:id => 1)

        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should not use the query conditions to set default values' do
        @resource.id.should be_nil
      end
    end

    describe 'when scoped to a property with multiple values' do
      before :all do
        @articles = @articles.all(:content => %w[ Sample Other ])

        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should not use the query conditions to set default values' do
        @resource.content.should be_nil
      end
    end

    describe 'when scoped with a condition other than eql' do
      before :all do
        @articles = @articles.all(:content.not => 'Sample')

        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should not use the query conditions to set default values' do
        @resource.content.should be_nil
      end
    end
  end

  it { @articles.should respond_to(:pop) }

  describe '#pop' do
    before :all do
      @new = @articles.create(:title => 'Sample Article')  # TODO: freeze @new

      @return = @resource = @articles.pop
    end

    it 'should return a Resource' do
      @return.should be_kind_of(DataMapper::Resource)
    end

    it 'should be the last Resource in the Collection' do
      @resource.should == @new
    end

    it 'should remove the Resource from the Collection' do
      @articles.should_not be_include(@resource)
    end

    it 'should orphan the Resource' do
      @resource.collection.should_not equal(@articles)
    end
  end

  it { @articles.should respond_to(:push) }

  describe '#push' do
    before :all do
      @resources = [ @article_model.new(:title => 'Title 1'), @article_model.new(:title => 'Title 2') ]

      @return = @articles.push(*@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should append the Resources to the Collection' do
      @articles.should == [ @article ] + @resources
    end

    it 'should relate the Resources to the Collection' do
      @resources.each { |resource| resource.collection.should equal(@articles) }
    end
  end

  it { @articles.should respond_to(:reject!) }

  describe '#reject!' do
    describe 'with a block that matches a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.reject! { true }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'with a block that does not match a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.reject! { false }
      end

      it 'should return nil' do
        @return.should be_nil
      end

      it 'should not modify the Collection' do
        @articles.should == @resources
      end
    end
  end

  it { @articles.should respond_to(:reload) }

  describe '#reload' do
    describe 'with no arguments' do
      before :all do
        @resources = @articles.dup.entries

        @return = @collection = @articles.reload
      end

      # FIXME: this is spec order dependent, move this into a helper method
      # and execute in the before :all block
      unless loaded
        it 'should not be a kicker' do
          pending do
            @articles.should_not be_loaded
          end
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      { :title => true, :content => false }.each do |attribute, expected|
        it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
          @collection.each { |resource| resource.attribute_loaded?(attribute).should == expected }
        end
      end
    end

    describe 'with a Hash query' do
      before :all do
        @resources = @articles.dup.entries

        @return = @collection = @articles.reload(:fields => [ :content ])  # :title is a default field
      end

      # FIXME: this is spec order dependent, move this into a helper method
      # and execute in the before :all block
      unless loaded
        it 'should not be a kicker' do
          pending do
            @articles.should_not be_loaded
          end
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      { :id => true, :content => true, :title => true }.each do |attribute, expected|
        it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
          @collection.each { |resource| resource.attribute_loaded?(attribute).should == expected }
        end
      end
    end

    describe 'with a Query' do
      before :all do
        @query = DataMapper::Query.new(@repository, @article_model, :fields => [ :content ])  # :title is an original field

        @return = @collection = @articles.reload(@query)
      end

      # FIXME: this is spec order dependent, move this into a helper method
      # and execute in the before :all block
      unless loaded
        it 'should not be a kicker' do
          pending do
            @articles.should_not be_loaded
          end
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      { :id => true, :content => true, :title => loaded }.each do |attribute, expected|
        it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
          pending_if "TODO: #{@articles.class}#reload should not be a kicker", @one_to_many && loaded == false && attribute == :title do
            @collection.each { |resource| resource.attribute_loaded?(attribute).should == expected }
          end
        end
      end
    end
  end

  it { @articles.should respond_to(:replace) }

  describe '#replace' do
    describe 'when provided an Array of Resources' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.replace(@other_articles)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should update the Collection with new Resources' do
        @articles.should == @other_articles
      end

      it 'should relate each Resource added to the Collection' do
        @articles.each { |resource| resource.collection.should equal(@articles) }
      end

      it 'should orphan each Resource removed from the Collection' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'when provided an Array of Hashes' do
      before :all do
        @array = [ { :content => 'From Hash' } ].freeze

        @return = @articles.replace(@array)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should initialize a Resource' do
        @return.first.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @return.first.should be_new
      end

      it 'should be a Resource with attributes matching the Hash' do
        @return.first.attributes.only(*@array.first.keys).should == @array.first
      end
    end
  end

  it { @articles.should respond_to(:reverse!) }

  describe '#reverse!' do
    before :all do
      @query = @articles.query

      @new = @articles.create(:title => 'Sample Article')

      @return = @articles.reverse!
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should return a Collection with reversed entries' do
      @return.should == [ @new, @article ]
    end

    it 'should return a Query that equal to the original' do
      @return.query.should equal(@query)
    end
  end

  [ :save, :save! ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      describe 'when Resources are not saved' do
        before :all do
          @articles.new(:title => 'New Article', :content => 'New Article')

          @return = @articles.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should save each Resource' do
          @articles.each { |resource| resource.should be_saved }
        end
      end

      describe 'when Resources have been orphaned' do
        before :all do
          @resources = @articles.entries
          @articles.replace([])

          @return = @articles.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should orphan the Resources' do
          @resources.each { |resource| resource.collection.should_not equal(@articles) }
        end
      end
    end
  end

  it { @articles.should respond_to(:shift) }

  describe '#shift' do
    before :all do
      @new = @articles.create(:title => 'Sample Article')

      @return = @resource = @articles.shift
    end

    it 'should return a Resource' do
      @return.should be_kind_of(DataMapper::Resource)
    end

    it 'should be the first Resource in the Collection' do
      @resource.key.should == @article.key
    end

    it 'should remove the Resource from the Collection' do
      @articles.should_not be_include(@resource)
    end

    it 'should orphan the Resource' do
      @resource.collection.should_not equal(@articles)
    end
  end

  it { @articles.should respond_to(:slice!) }

  describe '#slice!' do
    before :all do
      1.upto(10) { |number| @articles.create(:content => "Article #{number}") }

      @copy = @articles.dup
    end

    describe 'with a positive offset' do
      before :all do
        unless @skip
          @return = @resource = @articles.slice!(0)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @return.key.should == @article.key
      end

      it 'should return the same as Array#slice!' do
        @return.should == @copy.entries.slice!(0)
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with a positive offset and length' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(5, 5)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resource' do
        @return.should == @copy.entries.slice!(5, 5)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(5, 5)
      end
    end

    describe 'with a positive range' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(5..10)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(5..10)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(5..10)
      end
    end

    describe 'with a negative offset' do
      before :all do
        unless @skip
          @return = @resource = @articles.slice!(-1)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @return.should == @copy.entries.slice!(-1)
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with a negative offset and length' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(-5, 5)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(-5, 5)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(-5, 5)
      end
    end

    describe 'with a negative range' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(-3..-2)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(-3..-2)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(-3..-2)
      end
    end

    describe 'with an offset not within the Collection' do
      before :all do
        unless @skip
          @return = @articles.slice!(12)
        end
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with an offset and length not within the Collection' do
      before :all do
        unless @skip
          @return = @articles.slice!(12, 1)
        end
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with a range not within the Collection' do
      before :all do
        unless @skip
          @return = @articles.slice!(12..13)
        end
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it { @articles.should respond_to(:sort!) }

  describe '#sort!' do
    describe 'without a block' do
      before :all do
        @return = @articles.unshift(@other).sort!
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should modify and sort the Collection using default sort order' do
        @articles.should == [ @article, @other ]
      end
    end

    describe 'with a block' do
      before :all do
        @return = @articles.unshift(@other).sort! { |a_resource, b_resource| b_resource.id <=> a_resource.id }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should modify and sort the Collection using supplied block' do
        @articles.should == [ @other, @article ]
      end
    end
  end

  [ :splice, :[]= ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      before :all do
        unless @skip
          orphans = (1..10).map do |number|
            articles = @articles.dup
            articles.create(:content => "Article #{number}")
            articles.pop  # remove the article from the tail
          end

          @articles.unshift(*orphans.first(5))
          @articles.concat(orphans.last(5))

          unless loaded
            @articles.should_not be_loaded
          end

          @copy = @articles.dup
          @new = @article_model.new(:content => 'New Article')
        end
      end

      describe 'with a positive offset and a Resource' do
        before :all do
          rescue_if 'TODO', @skip do
            @original = @copy[1]
            @original.collection.should equal(@articles)

            @return = @resource = @articles.send(method, 1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should equal(@articles)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not equal(@articles)
        end
      end

      describe 'with a positive offset and length and a Resource' do
        before :all do
          rescue_if 'TODO', @skip do
            @original = @copy[2]
            @original.collection.should equal(@articles)

            @return = @resource = @articles.send(method, 2, 1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[2, 1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not equal(@articles)
        end
      end

      describe 'with a positive range and a Resource' do
        before :all do
          rescue_if 'TODO', @skip do
            @originals = @copy.values_at(2..3)
            @originals.each { |resource| resource.collection.should equal(@articles) }

            @return = @resource = @articles.send(method, 2..3, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resources' do
            @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[2..3] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should orphan the original Resources' do
          @originals.each { |resource| resource.collection.should_not equal(@articles) }
        end
      end

      describe 'with a negative offset and a Resource' do
        before :all do
          rescue_if 'TODO', @skip do
            @original = @copy[-1]
            @original.collection.should equal(@articles)

            @return = @resource = @articles.send(method, -1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should equal(@articles)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not equal(@articles)
        end
      end

      describe 'with a negative offset and length and a Resource' do
        before :all do
          rescue_if 'TODO', @skip do
            @original = @copy[-2]
            @original.collection.should equal(@articles)

            @return = @resource = @articles.send(method, -2, 1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-2, 1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not equal(@articles)
        end
      end

      describe 'with a negative range and a Resource' do
        before :all do
          rescue_if 'TODO', @skip do
            @originals = @copy.values_at(-3..-2)
            @originals.each { |resource| resource.collection.should equal(@articles) }

            @return = @resource = @articles.send(method, -3..-2, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resources' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-3..-2] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should orphan the original Resources' do
          @originals.each { |resource| resource.collection.should_not equal(@articles) }
        end
      end
    end
  end

  describe '#[]=' do
    describe 'when swapping resources' do
      before :all do
        rescue_if 'TODO', @skip do
          @articles.create(:content => 'Another Article')

          @entries = @articles.entries

          @articles[0], @articles[1] = @articles[1], @articles[0]
        end
      end

      it 'should include the Resource in the Collection' do
        @articles.should == @entries.reverse
      end

      it 'should relate the Resource to the Collection' do
        @articles.each { |resource| resource.collection.should equal(@articles) }
      end
    end
  end

  it { @articles.should respond_to(:unshift) }

  describe '#unshift' do
    before :all do
      @resources = [ @article_model.new(:title => 'Title 1'), @article_model.new(:title => 'Title 2') ]

      @return = @articles.unshift(*@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should prepend the Resources to the Collection' do
      @articles.should == @resources + [ @article ]
    end

    it 'should relate the Resources to the Collection' do
      @resources.each { |resource| resource.collection.should equal(@articles) }
    end
  end

  [ :update, :update! ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      describe 'with no arguments' do
        before :all do
          @return = @articles.send(method)
        end

        if method == :update!
          should_not_be_a_kicker
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'with attributes' do
        before :all do
          @attributes = { :title => 'Updated Title' }

          @return = @articles.send(method, @attributes)
        end

        if method == :update!
          # FIXME: this is spec order dependent, move this into a helper method
          # and execute in the before :all block
          unless loaded
            it 'should not be a kicker' do
              pending_if 'TODO', @many_to_many do
                @articles.should_not be_loaded
              end
            end
          end
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should update attributes of all Resources' do
          @articles.each { |resource| @attributes.each { |key, value| resource.send(key).should == value } }
        end

        it 'should persist the changes' do
          resource = @article_model.get(*@article.key)
          @attributes.each { |key, value| resource.send(key).should == value }
        end
      end

      describe 'with attributes where one is a parent association' do
        before :all do
          @attributes = { :original => @other }

          @return = @articles.send(method, @attributes)
        end

        if method == :update!
          # FIXME: this is spec order dependent, move this into a helper method
          # and execute in the before :all block
          unless loaded
            it 'should not be a kicker' do
              pending_if 'TODO', @many_to_many do
                @articles.should_not be_loaded
              end
            end
          end
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should update attributes of all Resources' do
          @articles.each { |resource| @attributes.each { |key, value| resource.send(key).should == value } }
        end

        it 'should persist the changes' do
          resource = @article_model.get(*@article.key)
          @attributes.each { |key, value| resource.send(key).should == value }
        end
      end

      describe 'with attributes where a not-nullable property is nil' do
        before :all do
          @return = @articles.send(method, :title => nil)
        end

        if method == :update!
          should_not_be_a_kicker
        end

        it 'should return false' do
          @return.should be_false
        end
      end

      describe 'on a limited collection' do
        before :all do
          @other      = @articles.create
          @limited    = @articles.all(:limit => 1)
          @attributes = { :content => 'Updated Content' }

          @return = @limited.send(method, @attributes)
        end

        if method == :update!
          # FIXME: this is spec order dependent, move this into a helper method
          # and execute in the before :all block
          unless loaded
            it 'should not be a kicker' do
              pending "Update Collection##{method} to use a subquery" do
                @limited.should_not be_loaded
              end
            end
          end
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should bypass validation' do
          pending 'TODO: not sure how to best spec this'
        end

        it 'should update attributes of all Resources' do
          @limited.each { |resource| @attributes.each { |key, value| resource.send(key).should == value } }
        end

        it 'should persist the changes' do
          resource = @article_model.get(*@article.key)
          @attributes.each { |key, value| resource.send(key).should == value }
        end

        it 'should not update the other Resource' do
          @other.reload
          @attributes.each { |key, value| @other.send(key).should_not == value }
        end
      end
    end
  end
end
