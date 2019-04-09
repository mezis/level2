require 'spec_helper'
require 'active_support/cache/level2'
require 'active_support/notifications'
require 'pry'
require 'timecop'

describe ActiveSupport::Cache::Level2 do
  subject do
    ActiveSupport::Cache.lookup_store :level2,
      name: 'SomeName',
      L1: [
        :memory_store, { size: 10.megabytes }
      ],
      L2: [
        :memory_store, { size: 5.megabytes }
      ]
  end

  let(:level1) { subject.stores.values.first }
  let(:level2) { subject.stores.values.last }

  it 'can be initialized' do
    expect { subject }.not_to raise_error
  end

  describe 'cache behaviour' do
    it 'can #write' do
      expect(subject.write('foo', 'bar')).to be_truthy
    end

    it 'prefixes values' do
      subject.write('foo', 'bar')

      expect(level1.read('SomeName::foo')).to eq 'bar'
    end

    it 'can #read' do
      subject.write('foo', 'bar')
      expect(subject.read('foo')).to eq('bar')
    end

    it 'can #delete' do
      subject.write('foo', 'bar')
      subject.delete('foo')
      expect(subject.read('foo')).to be_nil
    end

    it 'can #fetch' do
      expect(
        subject.fetch('foo') { 'bar' }
      ).to eq('bar')

      expect(
        subject.fetch('foo') { 'qux' }
      ).to eq('bar')
    end

    it 'honours expiry' do
      subject.write('foo', 'bar', expires_in: 0)
      expect(subject.read('foo')).to be_nil
    end

    it 'can #clear' do
      subject.write('foo', 'bar')
      subject.clear
      expect(subject.read('foo')).to be_nil
    end
  end

  describe 'storage' do
    it 'writes to all stores' do
      subject.write('foo', 'bar')
      expect(level1.read('SomeName::foo')).to eq('bar')
      expect(level2.read('SomeName::foo')).to eq('bar')
    end

    it 'reads from the top store' do
      level1.write('SomeName::foo', 'bar1')
      level2.write('SomeName::foo', 'bar2')
      expect(subject.read('foo')).to eq('bar1')
    end

    it 'can read from the bottom store' do
      level2.write('SomeName::foo', 'bar2')
      expect(subject.read('foo')).to eq('bar2')
    end

    it 'populates the top store on reads' do
      level2.write('SomeName::foo', 'bar2')
      subject.read('foo')
      expect(level1.read('SomeName::foo')).to eq('bar2')
    end
  end

  describe ':only restrictions' do
    it 'only writes to the selected store' do
      subject.write('foo', 'bar', only: :L2)
      expect(level1.read('SomeName::foo')).to be_nil
      expect(level2.read('SomeName::foo')).to eq('bar')
    end

    it 'only reads the selected store' do
      level1.write('SomeName::foo', 'bar1', only: :L2)
      level2.write('SomeName::foo', 'bar2', only: :L2)
      expect(subject.read('foo', only: :L1)).to eq('bar1')
      expect(subject.read('foo', only: :L2)).to eq('bar2')
    end
  end

  describe 'notifications' do
    after { ActiveSupport::Notifications.unsubscribe(//) }
    let(:events) { Hash.new{|h,k| h[k] = []} }

    before do
      ActiveSupport::Notifications.subscribe( /multi_layer_cache./) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        events[event.name.split('.').last] << event
      end
    end

    it 'notifies' do
      expect { subject.read('foo') }.to change {
        events['miss'].map(&:payload)
      } .to contain_exactly(
        include(store_name: 'SomeName', cache_name: :L1, cache: an_instance_of(ActiveSupport::Cache::MemoryStore)),
        include(store_name: 'SomeName',cache_name: :L2, cache: an_instance_of(ActiveSupport::Cache::MemoryStore))
      )
    end

    context 'on miss on only top levels' do
      it 'notifies' do
        expect {
          level2.write('SomeName::foo', 123)
          subject.read('foo')
        }.to change {
          events['miss'].map(&:payload)
        }.to(include(a_hash_including(store_name: 'SomeName', cache_name: :L1, cache: an_instance_of(ActiveSupport::Cache::MemoryStore))))
          .and change {
          events['hit'].map(&:payload)
        }.to(include(a_hash_including(store_name: 'SomeName', cache_name: :L2, cache: an_instance_of(ActiveSupport::Cache::MemoryStore))))
      end
    end

    context 'when the hit is expired' do
      it 'records the expired_hit' do
        Timecop.freeze do
          subject.write('foo', 123, expires_in: 2.seconds)
          Timecop.travel(Time.now.to_i + 10)

          expect {
            subject.read('foo')
          }.to change {
            events['expired_hit'].map(&:payload)
          }.to(include(a_hash_including(store_name: 'SomeName', cache_name: :L1, cache: an_instance_of(ActiveSupport::Cache::MemoryStore))))
        end
      end
    end

    describe '#write' do
      let(:perform) { subject.write('foo', 'bar') }

      it 'notifies' do
        expect { perform }.to change {
          events['write'].map(&:payload)
        }.to(include(
          a_hash_including(store_name: 'SomeName', cache_name: :L1),
          a_hash_including(store_name: 'SomeName', cache_name: :L2)
        ))
      end
    end

    describe '#delete' do
      let(:perform) { subject.delete('foo') }

      it 'notifies' do
        expect { perform }.to change {
          events['delete'].map(&:payload)
        }.to(include(
          a_hash_including(store_name: 'SomeName', cache_name: :L1),
          a_hash_including(store_name: 'SomeName', cache_name: :L2)
        ))
      end
    end

    describe '#read' do
      let(:perform) { subject.read('foo') }

      it 'notifies' do
        expect { perform }.to change {
          events['read'].map(&:payload)
        }.to(include(
          a_hash_including(store_name: 'SomeName', cache_name: :L1),
          a_hash_including(store_name: 'SomeName', cache_name: :L2)
        ))
      end
    end
  end
end
