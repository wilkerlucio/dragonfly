require 'rack'
require 'digest/sha1'

module Dragonfly
  class Parameters
    
    # Exceptions
    class InvalidParameters < RuntimeError; end
    class InvalidShortcut < RuntimeError; end

    # Class methods
    class << self
      
      include Configurable
      
      configurable_attr :default_processing_method
      configurable_attr :default_processing_options, {}
      configurable_attr :default_format
      configurable_attr :default_encoding, {}
      configurable_attr :default_default
      
      def new_with_defaults(attributes={})
        new({
          :processing_method => default_processing_method,
          :processing_options => default_processing_options,
          :format => default_format,
          :encoding => default_encoding,
          :default => default_default
        }.merge(attributes))
      end
      
      def add_shortcut(*args, &block)
        if block
          block_shortcuts_of_length(args.length).unshift([args, block])
        else
          shortcut_name, attributes = args
          simple_shortcuts[shortcut_name] = attributes
        end
      end
      configuration_method :add_shortcut
      
      def hash_from_shortcut(*args)
        if attributes = matching_simple_shortcut(args)
          attributes
        elsif attributes = matching_block_shortcut(args)
          attributes
        else
          raise InvalidShortcut, "No shortcut was found matching (#{args.map{|a| a.inspect }.join(', ')})"
        end
      end
      configuration_method :hash_from_shortcut
      
      def from_shortcut(*args)
        new_with_defaults(hash_from_shortcut(*args))
      end
      
      def from_args(*args)
        if args.empty? then new_with_defaults
        elsif args.length == 1 && args.first.is_a?(Hash) then new_with_defaults(args.first)
        elsif args.length == 1 && args.first.is_a?(Parameters) then args.first.dup
        else from_shortcut(*args)
        end
      end
      
      private
      
      def simple_shortcuts
        @simple_shortcuts ||= {}
      end
      
      # block_shortcuts is actually a hash (keyed on the number of
      # arguments) of arrays (of argument lists)
      def block_shortcuts
        @block_shortcuts ||= {}
      end
      
      def block_shortcuts_of_length(arg_length)
        block_shortcuts[arg_length] ||= []
      end
      
      def matching_simple_shortcut(args)
        if args.length == 1 && args.first.is_a?(Symbol)
          simple_shortcuts[args.first]
        end
      end
      
      def matching_block_shortcut(args)
        block_shortcuts_of_length(args.length).each do |(args_to_match, block)|
          if all_args_match?(args, args_to_match)
            # If the block shortcut arg is a single regexp, then also yield the match data
            if args_to_match.length == 1 && args_to_match.first.is_a?(Regexp)
              match_data = args_to_match.first.match(args.first)
              return block.call(args.first, match_data)
            # ...otherwise just yield the args
            else
              return block.call(*args)
            end
          end
        end
        nil
      end
      
      def all_args_match?(args, args_to_match)
        (0...args.length).inject(true){|current_result, i| current_result &&= args_to_match[i] === args[i] }
      end

    end

    # Instance methods

    def initialize(attributes={})
      attributes = attributes.dup
      self.uid                = attributes.delete(:uid)
      self.processing_method  = attributes.delete(:processing_method)
      self.processing_options = attributes.delete(:processing_options) || {}
      self.format             = attributes.delete(:format)
      self.encoding           = attributes.delete(:encoding) || {}
      self.default            = attributes.delete(:default) || nil
      raise ArgumentError, "Parameters doesn't recognise the following parameters: #{attributes.keys.join(', ')}" if attributes.any?
    end

    attr_accessor :uid, :processing_method, :processing_options, :format, :encoding, :default
    
    def [](attribute)
      send(attribute)
    end
    
    def []=(attribute, value)
      send("#{attribute}=", value)
    end
    
    def ==(other_parameters)
      self.to_hash == other_parameters.to_hash
    end
    
    def generate_sha(salt, sha_length)
      Digest::SHA1.hexdigest("#{to_sorted_array}#{salt}")[0...sha_length]
    end
    
    def unique_signature
      generate_sha('I like cheese', 10)
    end

    def to_hash
      {
        :uid => uid,
        :processing_method => processing_method,
        :processing_options => processing_options,
        :format => format,
        :encoding => encoding,
        :default => default
      }
    end

    private
    
    def to_sorted_array
      [
        uid,
        format.to_s,
        processing_method.to_s,
        processing_options.sort{|a,b| a[0].to_s <=> b[0].to_s },
        encoding.sort{|a,b| a[0].to_s <=> b[0].to_s },
        default
      ]
    end

  end
end