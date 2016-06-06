require 'spec_helper'
require 'active_support/cache/level2'
require 'pry'

describe ActiveSupport::Cache::Level2 do
  subject do
    ActiveSupport::Cache.lookup_store :level2,
      :memory_store, { size: 10.megabytes },
      :memory_store, { size: 5.megabytes }
  end

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
  end

  describe 'storage' do
    let(:level1) { subject.stores.first }
    let(:level2) { subject.stores.last }

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

end
