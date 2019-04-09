# Level2 [![Build Status](https://travis-ci.org/mezis/level2.svg)](https://travis-ci.org/mezis/level2) [![Gem Version](https://badge.fury.io/rb/level2.svg)](https://badge.fury.io/rb/level2)

A gem for tiered Rails caching.

This lets you "stack" Rails caches: you can use a smaller, faster cache for the
hotest cached items, and a larger, slower cache for more — mimicking how
microprocessors commonly have a small, ultrafast L1 cache and slower L2 and L3
caches.

A common idiom is to use Rails's
[`memory_store`](http://guides.rubyonrails.org/caching_with_rails.html#activesupport-cache-memorystore)
as the first level, and
[`mem_cache_store`](http://guides.rubyonrails.org/caching_with_rails.html#activesupport-cache-memcachestore)
or
[`redis_store`](https://github.com/redis-store/redis-store/wiki/Frameworks-Configuration)
as the second.

If your production setup has multiple Ruby processes per server, and some free
memory on servers, it can be more sensible to run one `mem_cache_store` per
server plus a shared one.

## Behaviour

- When reading a cache key, try reading from the first level first, then go down
  the list: if a key is in L1 and L2, the value in L1 will be returned —
  honouring expiry.
- Higher levels of cache are populated when reading: if a key is in L2 but not
  L1, it will be added to L1.
- When writing a key, it is written to all levels.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'level2'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install level2

## Usage

Level2 is configured like any other Rails cache store. Its array of options are passed to
the same store lookup.

Example:

```ruby
# in config/application.rb

config.cache_store = :level2, {
  L1: [ :memory_store, size: 32.megabytes ],
  L2: [ :mem_cache_store, 'host1.example.org:11211' ]
}
```

From thereon,

- `Rails.cache.read` and `.fetch` will read from `L1` and fall back to `L2` if
  the key is absent from `L1`.
- On L1 misses and L2 hits, L1 will be populated.
- `Rails.cache.write` and `.fetch` will write to both stores.

While discouraged, it is possible to write directly to a given cache level:

```ruby
Rails.cache.write('foo', 'bar', only: :L2)
```

This can be useful in cases where `L1` is a non-shared cache (e.g. in-memory
cache) and `L2` is shared (e.g. Redis, Memcached); and you want to keep the
ability to bust the cache manually.


## Notifications

Notifications are sent for every action taking on each cache layer of the cache.

All actions can be subscribed to  using an ActiveSupport::Notification
subscription using the pattern `multi_layer_cache.event_type`. All events
contain the Store Name (provided at construction), the layer name, and the
cache instance itself.


| Action      | Timed | Description                                                                      |
|-------------|-------|----------------------------------------------------------------------------------|
| read        | Yes   | Called when reading from a cache layer                                           |
| write       | Yes   | Called when writing to a cache layer                                             |
| hit         | No    | Called when a cache layer has a hit after read                                   |
| miss        | No    | Called when a cache layer has a miss after read                                  |
| expired_hit | No    | Called when a cache layer has a hit after read, but the entry is already expired |
| delete      | Yes   | Called on every layer when a record is removed                                   |


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mezis/level2.


## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).

