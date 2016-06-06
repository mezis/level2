require 'active_support/cache'

module ActiveSupport
  module Cache
    class Level2 < Store
      attr_reader :stores

      def initialize(*store_options)
        @lock = Mutex.new
        @stores = store_options.each_slice(2).map do |name,options|
          ActiveSupport::Cache.lookup_store(name, options)
        end
        @options = {}
      end

      def cleanup(options = nil)
        @lock.synchronize do
          @stores.each { |s| s.cleanup(options) }
        end
      end

      def clear(options = nil)
        @lock.synchronize do
          @stores.each { |s| s.clear(options) }
        end
      end

      protected

      def read_entry(key, options)
        @lock.synchronize do
          read_entry_from(@stores, key, options)
        end
      end

      def write_entry(key, entry, options)
        @lock.synchronize do
          @stores.each do |store|
            result = store.send :write_entry, key, entry, options
            return false unless result
          end
          true
        end
      end

      def delete_entry(key, options)
        @lock.synchronize do
          @stores.map { |store|
            store.send :delete_entry, key, options
          }.all?
        end
      end

      private

      def read_entry_from(stores, key, options)
        return if stores.empty?

        store, *other_stores = stores
        entry = store.send :read_entry, key, options
        return entry if entry.present?

        entry = read_entry_from(other_stores, key, options)
        return nil unless entry.present?
        store.send :write_entry, key, entry, {}
        
        entry
      end
    end
  end
end
