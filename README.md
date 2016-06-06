# Level2

A gem for tiered Rails caching.

This lets you "stack" Rails caches: you can use a smaller, faster cache for the
hotest cached items, and a larger, slower cache for more — mimicking how
microprocessors commonly have a small, ultrafast L1 cache and slower L2 and L3
caches.

A common idiom is to use Rails's [`memory_store`]() as the first level, and
[`mem_cache_store`]() or [`redis_store`]() as the second.

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

config.cache_store = :level2, [
    :memory_store, size: 32.megabytes
  ],[
    :mem_cache_store, 'host1.example.org:11211', 'host2.example.org:11211'
  ]
```



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

