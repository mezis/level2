require 'spec_helper'
require 'active_support/cache/level2'
require 'active_support/notifications'
require 'pry'

describe ActiveSupport::Cache::Level2 do
  subject do
    ActiveSupport::Cache.lookup_store :level2,
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
      expect(level1.read('foo')).to eq('bar')
      expect(level2.read('foo')).to eq('bar')
    end

    it 'reads from the top store' do
      level1.write('foo', 'bar1')
      level2.write('foo', 'bar2')
      expect(subject.read('foo')).to eq('bar1')
    end

    it 'can read from the bottom store' do
      level2.write('foo', 'bar2')
      expect(subject.read('foo')).to eq('bar2')
    end

    it 'populates the top store on reads' do
      level2.write('foo', 'bar2')
      subject.read('foo')
      expect(level1.read('foo')).to eq('bar2')
    end
  end

  describe ':only restrictions' do
    it 'only writes to the selected store' do
      subject.write('foo', 'bar', only: :L2)
      expect(level1.read('foo')).to be_nil
      expect(level2.read('foo')).to eq('bar')
    end

    it 'only reads the selected store' do
      level1.write('foo', 'bar1', only: :L2)
      level2.write('foo', 'bar2', only: :L2)
      expect(subject.read('foo', only: :L1)).to eq('bar1')
      expect(subject.read('foo', only: :L2)).to eq('bar2')
    end
  end

  describe 'notifications' do
    after { ActiveSupport::Notifications.unsubscribe(//) }
    let(:events) { [] }

    describe '#read' do
      before do
        ActiveSupport::Notifications.subscribe('cache_read.active_support') do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end
      end

      context 'on miss' do
        before { subject.read('foo') }

        it { expect(events.length).to eq 1 }
        it { expect(events.first.payload[:hit]).to eq false }
      end

      context 'on first hit' do
        before { level2.write('foo', 'bar') }
        before { subject.read('foo') }

        it { expect(events.last.payload[:level]).to eq :L2 }
        it { expect(events.last.payload[:hit]).to eq true }
      end

      context 'on second hit' do
        before { level2.write('foo', 'bar') }
        before { 2.times { subject.read('foo') } }

        it { expect(events.last.payload[:level]).to eq :L1 }
        it { expect(events.last.payload[:hit]).to eq true }
      end
    end

    describe '#write' do
      let(:perform) { subject.write('foo', 'bar') }

      before do
        ActiveSupport::Notifications.subscribe('cache_write.active_support') do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end
      end

      it 'notifies' do
        perform
        expect(events.length).to eq 1
      end
    end
  end
  
  # it { binding.pry }
end
