require 'active_support/cache'

require 'active_support/version'
if ActiveSupport::VERSION::MAJOR == 3
  # active_support/cache actually depends on this but doesn't require it:
  require 'securerandom'
end

module ActiveSupport
  module Cache
    class Level2 < Store
      attr_reader :stores

      def initialize(store_options)
        @stores = store_options.each_with_object({}) do |(name,options), h|
          h[name] = ActiveSupport::Cache.lookup_store(options)
        end
        @options = {}
      end

      def cleanup(*args)
        @stores.each_value { |s| s.cleanup(*args) }
      end

      def clear(*args)
        @stores.each_value { |s| s.clear(*args) }
      end

      def read_multi(*names)
        result = {}
        @stores.each do |_name,store|
          data = store.read_multi(*names)
          result.merge! data
          names -= data.keys
        end
        result
      end


      protected

      def instrument(operation, key, options = {})
        puts "Calling instrument #{operation} - #{key}, #{options}"
        super(operation, key, options.merge(level: current_level))
      end

      def read_entry(key, options)
        stores = selected_stores(options)
        read_entry_from(stores, key, options)
      end

      def write_entry(key, entry, options)
        in_each_store(selected_stores(options)) do |_name, store|
          !!store.send(:write_entry, key, entry, options)
        end
      end

      def delete_entry(key, options)
        selected_stores(options).each do |_, store|
          store.send :delete_entry, key, options
        end
      end

      private

      def in_each_store(stores)
        stores.collect do |name, store|
          Thread.new { yield name, store }
        end.map(&:value)
      end

      def current_level
        Thread.current[:level2_current]
      end

      def current_level!(name)
        Thread.current[:level2_current] = name
      end

      def read_entry_from(stores, key, options)
        return if stores.empty?

        stores_without_entry = []

        entry = stores.lazy.map do |name, store|
          current_level! name
          entry = store.send :read_entry, key, options

          stores_without_entry << name unless entry

          entry
        end.detect(&:itself)

        return unless entry

        unless stores_without_entry.empty?
          write_entry(key, entry, options.merge(only: stores_without_entry))
        end

        entry
      end

      def selected_stores(options)
        only = options[:only]

        if only.nil?
          current_level! :all
          @stores
        else
          only = [only] unless only.is_a?(Array)
          current_level! only
          @stores.select { |name,_| only.include?(name)  }
        end
      end
    end
  end
end
