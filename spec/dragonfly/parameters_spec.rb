require File.dirname(__FILE__) + '/../spec_helper'

describe Dragonfly::Parameters do
  
  def standard_attributes
    {
      :uid => 'ahaha',
      :processing_method => :round,
      :format => :gif,
      :processing_options => {:radius => 5},
      :encoding => {:flumps_per_minute => 56},
      :default => "default_image.png"
    }
  end
  
  describe "initializing" do
    it "should allow initializing without a hash" do
      parameters = Dragonfly::Parameters.new
      parameters.uid.should be_nil
    end
    it "should allow initializing with a hash" do
      parameters = Dragonfly::Parameters.new(:uid => 'b')
      parameters.uid.should == 'b'
    end
    it "should raise an error if initialized with a bad hash key" do
      lambda{
        Dragonfly::Parameters.new(:fridge => 'cold')
      }.should raise_error(ArgumentError)
    end
  end
  
  describe "accessors" do
    before(:each) do
      @parameters = Dragonfly::Parameters.new
    end
    it "should give the accessors the correct defaults" do
      @parameters.uid.should be_nil
      @parameters.processing_method.should be_nil
      @parameters.format.should be_nil
      @parameters.processing_options.should == {}
      @parameters.encoding.should == {}
      @parameters.default.should be_nil
    end
    it "should provide writers too" do
      @parameters.uid = 'hello'
      @parameters.uid.should == 'hello'
    end
  end
  
  describe "array style accessors" do
    before(:each) do
      @parameters = Dragonfly::Parameters.new(:uid => 'hello')
    end
    it "should be the same as calling the corresponding reader" do
      @parameters[:uid].should == @parameters.uid
    end
    it "should be the same as calling the corresponding writer" do
      @parameters[:uid] = 'goodbye'
      @parameters.uid.should == 'goodbye'
    end
  end
  
  describe "comparing" do
    before(:each) do
      @parameters1 = Dragonfly::Parameters.new(standard_attributes)
      @parameters2 = Dragonfly::Parameters.new(standard_attributes)      
    end
    it "should return true when two have all the same attributes" do
      @parameters1.should == @parameters2
    end
    %w(uid processing_method format processing_options encoding).each do |attribute|
      it "should return false when #{attribute} is different" do
        @parameters2[attribute.to_sym] = 'fish'
        @parameters1.should_not == @parameters2
      end
    end
  end
  
  describe "to_hash" do
    it "should return the attributes as a hash" do
      parameters = Dragonfly::Parameters.new(standard_attributes)
      parameters.to_hash.should == standard_attributes
    end
  end
  
  describe "custom parameters classes" do
    
    before(:each) do
      @parameters_class = Class.new(Dragonfly::Parameters)
    end
    
    describe "when defaults are not set" do
      it "should return the standard defaults" do
        parameters = @parameters_class.new_with_defaults
        parameters.processing_method.should be_nil
        parameters.processing_options.should == {}
        parameters.format.should be_nil
        parameters.encoding.should == {}
      end
    end
    
    describe "when defaults are set" do
      before(:each) do
        @parameters_class.configure do |c|
          c.default_processing_method = :resize
          c.default_processing_options = {:scale => '0.5'}
          c.default_format = :png
          c.default_encoding = {:bit_rate => 24}
          c.default_default = "default_image.png"
        end
      end
      it "should not affect .new" do
        parameters = @parameters_class.new
        parameters.processing_method.should be_nil
        parameters.processing_options.should == {}
        parameters.format.should be_nil
        parameters.encoding.should == {}
        parameters.default.should be_nil
      end
      it "should return the default if not set on parameters" do
        parameters = @parameters_class.new_with_defaults
        parameters.processing_method.should == :resize
        parameters.processing_options.should == {:scale => '0.5'}
        parameters.format.should == :png
        parameters.encoding.should == {:bit_rate => 24}
        parameters.default.should == "default_image.png"
      end
      it "should return the correct parameter if set" do
        parameters = @parameters_class.new_with_defaults(
          :processing_method => :yo,
          :processing_options => {:a => 'b'},
          :format => :txt,
          :encoding => {:ah => :arg},
          :default => "other_image.png"
        )
        parameters.processing_method.should == :yo
        parameters.processing_options.should == {:a => 'b'}
        parameters.format.should == :txt
        parameters.encoding.should == {:ah => :arg}
        parameters.default.should == "other_image.png"
      end
      it "should not override nil if explicity set" do
        @parameters_class.new_with_defaults(:format => nil).format.should be_nil
      end
    end
    
  end
  
  describe "shortcuts" do
    
    before(:each) do
      @parameters_class = Class.new(Dragonfly::Parameters)
    end
    
    it "should allow for setting simple shortcuts" do
      attributes = {
        :processing_method => :duncan,
        :processing_options => {:bill => :gates},
        :format => 'mamamia',
        :encoding => {:doogie => :howser},
        :default => nil
      }
      @parameters_class.add_shortcut(:doobie, attributes)
      @parameters_class.hash_from_shortcut(:doobie).should == attributes
    end
    
    it "should raise an error if the shortcut doesn't exist" do
      lambda{
        @parameters_class.hash_from_shortcut(:idontexist)
      }.should raise_error(Dragonfly::Parameters::InvalidShortcut)
    end
    
    describe "block shortcuts" do
      
      before(:each) do
        @parameters_class.add_shortcut(/^hello.*$/, Symbol) do |processing_method, format, matches|
          {:processing_method => processing_method, :format => format}
        end
      end
      
      it "should allow for more complex shortcuts by using a block and matching args" do
        @parameters_class.hash_from_shortcut('hellothere', :tif).should == {:processing_method => 'hellothere', :format => :tif}
      end

      it "should raise an error if the shortcut doesn't match properly" do
        lambda{
          @parameters_class.hash_from_shortcut('hellothere', 'tif')
        }.should raise_error(Dragonfly::Parameters::InvalidShortcut)
      end
      
      it "should raise an error if the shortcut matches but has the wrong number of args" do
        lambda{
          @parameters_class.hash_from_shortcut('hellothere', :tif, 'YO')
        }.should raise_error(Dragonfly::Parameters::InvalidShortcut)
      end

      it "should let later shortcuts have priority over earlier ones" do
        @parameters_class.add_shortcut(/hello/, :tif) do |a, b|
          {:processing_method => :bumble}
        end
        @parameters_class.hash_from_shortcut('hellothere', :tif).should == {:processing_method => :bumble}
      end

    end
    
    describe "single regexp shortcuts" do
      
      it "should yield regexp match data if the args is just one regexp" do
        @parameters_class.add_shortcut(/^hello(.*)$/) do |arg, match_data|
          {:processing_options => {:arg => arg, :match_data => match_data}}
        end
        processing_options = @parameters_class.hash_from_shortcut('hellothere')[:processing_options]
        processing_options[:arg].should == 'hellothere'
        processing_options[:match_data].should be_a(MatchData)
        processing_options[:match_data][1].should == 'there'
      end
      
    end
    
    describe ".from_shortcut" do
      before(:each) do
        @parameters_class.add_shortcut(/^hello.*$/) do |processing_method, matches|
          {:processing_method => processing_method}
        end
        @parameters_class.default_format = :tif
      end
      it "should just be the parameters equivalent of 'hash_from_shortcut', including defaults" do
        @parameters_class.from_shortcut('hellothere').should == 
          @parameters_class.new(@parameters_class.hash_from_shortcut('hellothere').merge(:format => :tif))
      end
    end
    
  end
  
  describe ".from_args" do
    
    before(:each) do
      @parameters_class = Class.new(Dragonfly::Parameters)
      @parameters_class.default_format = :tif
    end
    
    it "should be the same as 'new_with_defaults' if empty args" do
      @parameters_class.from_args.should == @parameters_class.new_with_defaults
    end
    
    it "should treat the arguments as actual parameter values (including defaults) if args is a single hash" do
      @parameters_class.from_args(:uid => 'some_uid', :processing_method => :resize).
        should == @parameters_class.new_with_defaults(:uid => 'some_uid', :processing_method => :resize)
    end

    it "should simply return the same parameters if args is a single parameters object" do
      @parameters_class.from_args(@parameters_class.new(:uid => 'some_uid', :processing_method => :resize)).
        should == @parameters_class.new(:uid => 'some_uid', :processing_method => :resize)
    end
    
    it "should treat the arguments as shortcut arguments otherwise" do
      @parameters_class.should_receive(:from_shortcut).with('innit').and_return(parameters = mock('parameters'))
      @parameters_class.from_args('innit').should == parameters
    end
    
  end
  
  describe "unique_signature" do
    
    before(:each) do
      @parameters = Dragonfly::Parameters.new(standard_attributes)
      @parameters2 = Dragonfly::Parameters.new(standard_attributes)
    end
    
    it "should a unique identifier based on its attributes" do
      @parameters.unique_signature.should be_a(String)
      @parameters.unique_signature.length.should > 0
    end
    
    it "should be the same if the attributes are the same" do
      @parameters.unique_signature.should == @parameters2.unique_signature
    end
    
    it "should be different when the uid is changed" do
      @parameters2.uid = 'different yo'
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
   
    it "should be different when the format is changed" do
      @parameters2.format = :tif
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
    
    it "should be different when the processing_method is changed" do
      @parameters2.processing_method = :doogie
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
   
    it "should be different when the processing_options are changed" do
      @parameters2.processing_options[:slumdog] = 'millionaire'
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
    
    it "should be different when the encoding options are changed" do
      @parameters2.encoding[:flumps_per_minute] = 50.3
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end

  end
  
end