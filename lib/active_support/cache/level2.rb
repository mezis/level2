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

      # Rails 3 doesn't instrument by default, this overrides it
      def self.instrument
        true
      end

      protected

      def instrument(operation, key, options = nil)
        super(operation, key, options) do |payload|
          yield(payload).tap do
            payload[:level] = current_level if payload
          end
        end
      end

      def read_entry(key, options)
        stores = selected_stores(options)
        read_entry_from(stores, key, options)
      end

      def write_entry(key, entry, options)
        stores = selected_stores(options)
        stores.each do |name, store|
          result = store.send :write_entry, key, entry, options
          return false unless result
        end
      end

      def delete_entry(key, options)
        selected_stores(options)
        stores.map { |name,store|
          store.send :delete_entry, key, options
        }.all?
      end

      private

      def current_level
        Thread.current[:level2_current]
      end

      def current_level!(name)
        Thread.current[:level2_current] = name
      end

      def read_entry_from(stores, key, options)
        return if stores.empty?

        (name,store), *other_stores = stores.to_a
        current_level! name
        entry = store.send :read_entry, key, options
        return entry if entry.present?

        entry = read_entry_from(other_stores, key, options)
        return nil unless entry.present?
        store.send :write_entry, key, entry, {}
        
        entry
      end

      def selected_stores(options)
        only = options[:only]
        return @stores if only.nil?
        @stores.select { |name,_| name == only }
      end

    end
  end
end
