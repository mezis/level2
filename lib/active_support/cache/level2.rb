require 'active_support/cache'

require 'active_support/version'
if ActiveSupport::VERSION::MAJOR == 3
  # active_support/cache actually depends on this but doesn't require it:
  require 'securerandom'
end

module ActiveSupport
  module Cache
    class Level2 < Store
      attr_reader :stores, :store_name

      def initialize(store_options)
        @store_name = store_options.delete(:name) || ''
        @stores = store_options.each_with_object({}) do |(name,options), h|
          h[name] = ActiveSupport::Cache.lookup_store(options)
        end
        provided_namespace = store_options[:namespace]
        store_options[:namespace] = proc do
          provided = provided_namespace.is_a?(Proc) ? provided_namespace.call : ''
          @store_name + ':' + provided
        end

        super(store_options)
      end

      def cleanup(*args)
        @stores.each_value { |s| s.cleanup(*args) }
      end

      def clear(*args)
        @stores.each_value { |s| s.clear(*args) }
      end

      protected

      def read_entry(key, options)
        stores = selected_stores(options)
        read_entry_from(stores, key, options)
      end

      def write_entry(key, entry, options)
        in_each_store(selected_stores(options)) do |name, store|
          !!store.send(:write_entry, key, entry, **options)
        end
      end

      def delete_entry(key, options)
        selected_stores(options).each do |name, store|
          store.send :delete_entry, key, **options
        end
      end

      private

      def in_each_store(stores)
        stores.collect do |name, store|
          Thread.new { yield name, store }
        end.map(&:value)
      end

      def read_entry_from(stores, key, options)
        return if stores.empty?

        stores_without_entry = []

        entry = stores.lazy.map do |name, store|
          entry = store.send :read_entry, key, **options

          if entry
            entry
          else
            stores_without_entry << name
            nil
          end
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
          @stores
        else
          only = [only] unless only.is_a?(Array)
          @stores.select { |name, _| only.include?(name) }
        end
      end
    end
  end
end
