require 'digest/sha1'
require 'rack'

module Dragonfly
  class UrlHandler
    
    # Exceptions
    class IncorrectSHA < RuntimeError; end
    class SHANotGiven < RuntimeError; end
    class UnknownUrl < RuntimeError; end
    
    include Rack::Utils
    include Configurable

    MAPPINGS = {
      :processing_method => 'm',
      :processing_options => 'o',
      :encoding => 'e',
      :default => 'd',
      :sha => 's'
    }
 
    configurable_attr :protect_from_dos_attacks, true
    configurable_attr :secret, 'This is a secret!'
    configurable_attr :sha_length, 16
    configurable_attr :path_prefix, ''

    def initialize(parameters_class = Parameters)
      @parameters_class = parameters_class
    end

    def url_for(uid, *args)
      parameters = parameters_class.from_args(*args)
      parameters.uid = uid
      parameters_to_url(parameters)
    end

    def url_to_parameters(path, query_string)
      path = unescape(path)
      validate_format!(path)
      path = remove_path_prefix(path)
      query = parse_nested_query(query_string)
      attributes = {
        :uid => extract_uid(path, query),
        :processing_method => extract_processing_method(path, query),
        :processing_options => extract_processing_options(path, query),
        :format => extract_format(path, query),
        :encoding => extract_encoding(path, query),
        :default => extract_default(path, query)
      }.reject{|k,v| v.nil? }
      parameters = parameters_class.new(attributes)
      validate_parameters(parameters, query)
      parameters
    end

    def parameters_to_url(parameters)
      query_string = [:processing_method, :processing_options, :encoding, :default].map do |attribute|
        build_query(MAPPINGS[attribute] => parameters[attribute]) unless parameters[attribute].blank?
      end.compact.join('&')
      sha_string = "&#{MAPPINGS[:sha]}=#{sha_from_parameters(parameters)}" if protect_from_dos_attacks?
      ext = ".#{parameters.format}" if parameters.format
      url = "#{path_prefix}/#{escape_except_for_slashes(parameters.uid)}#{ext}?#{query_string}#{sha_string}"
      url.sub!(/\?$/,'')
      url
    end

    private

    def remove_path_prefix(path)
      path.sub(path_prefix, '')
    end

    def extract_uid(path, query)
      path.sub(/^\//,'').sub(/\.[^.]+$/, '')
    end
  
    def extract_processing_method(path, query)
      query[MAPPINGS[:processing_method]]
    end
  
    def extract_processing_options(path, query)
      processing_options = query[MAPPINGS[:processing_options]]
      symbolize_keys(processing_options) if processing_options
    end
  
    def extract_format(path, query)
      bits = path.sub(/^\//,'').split('.')
      bits.last if bits.length > 1
    end
  
    def extract_encoding(path, query)
      encoding = query[MAPPINGS[:encoding]]
      symbolize_keys(encoding) if encoding
    end
    
    def extract_default(path, query)
      query[MAPPINGS[:default]]
    end

    attr_reader :parameters_class

    def symbolize_keys(hash)
      hash.inject({}) do |memo, (key, value)|
        memo[key.to_sym] = hash[key]
        memo
      end
    end

    def validate_parameters(parameters, query)
      if protect_from_dos_attacks?
        sha = query[MAPPINGS[:sha]]
        raise SHANotGiven, "You need to give a SHA" if sha.nil?
        raise IncorrectSHA, "The SHA parameter you gave is incorrect" if sha_from_parameters(parameters) != sha
      end
    end
    
    def protect_from_dos_attacks?
      protect_from_dos_attacks
    end
    
    def sha_from_parameters(parameters)
      parameters.generate_sha(secret, sha_length)
    end
    
    
    # Annoyingly, the 'build_query' in Rack::Utils doesn't seem to work
    # properly for nested parameters/arrays
    # Taken from http://github.com/sinatra/sinatra/commit/52658061d1205753a8afd2801845a910a6c01ffd
    def build_query(value, prefix = nil)
      case value
      when Array
        value.map { |v|
          build_query(v, "#{prefix}[]")
        } * "&"
      when Hash
        value.map { |k, v|
          build_query(v, prefix ? "#{prefix}[#{escape(k)}]" : escape(k))
        } * "&"
      else
        "#{prefix}=#{escape(value)}"
      end
    end
    
    def escape_except_for_slashes(string)
      string.split('/').map{|s| escape(s) }.join('/')
    end
    
    def validate_format!(path)
      raise UnknownUrl, "path '#{path}' not found" unless path =~ %r(^#{path_prefix}/[^.]+)
    end
    
  end
end