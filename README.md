flexcache
=======

Flexible cache for async function calls. It is designed for preventing dirty caches more then on speed.
Different Backends allows you to cover different usecases.


# Backends


## Redis


Best used for preventing long and slow operations on the filesysetem. Can easily be shared accross a Cluster and is
very performant. TTL support of the Redis database scales down the memory usage. 


## Memory (soon)


Caches are local only. Should only be used in a very narrow scope and be destoryed after every request. They are very
fast however.


# Installation


    npm install flexcache


# What can be cached

You can cache only data that can be serialized into a bson blob, which is more complete then json. 
Flexcache tries to prevent false positives and invalid cache state. Caches can be shared across multiple machines depending
on the backend.


# Cache Identifiers


Flexcache uses a two level cache.
First leve is called `group`, second level is the `hash`.
By using a easy to receive value as group key, you can clear all caches depending strongly on the state of your data.

For example. If you want to cache data that is calculated of data from a file or directory, you can choose those as cache group.
When you have changes to your data, simply call a `clear_group()` on your identifier.

You can also invalidate a hash without touching other hashes.

Default behaviour:

group: save\_hasher
hash: save\_hasher\_all


# Hashers


Hasher play a very important part in flexcache.
They may determine the group, but more importantly determine the hash to use.

hasher_one: (x,...)
    JSON.stringify(x)

hasher_all (args...)
    JSON.stringify(args)

safe_hasher_one (x)
    sha256(bson.serialize([x]))

safe_hasher_all (args...)
    sha256(bson.serialize(args...))

It is very important that you normalize the arguments somehow, so the same arguments result in the same hash and
you get a cache hit. Your hash function should prevent collisions.

The hash used on the database are prefixed. The key is prefixed with the Flexcache\'s group\_prefix. The hash is
prefixed with the cache name. By default the name of the wrapped function, but you have to make sure it is used
only once, if not, you need to provide one. Anonymous functions always need a name.


# Usage


Each Flexcache instance uses a backend for storage. Many Flexcache instances can share a backend, but may have
different options.

```javascript

RedisBackend = require('flexcache/backend/redis').RedisBackend
Flexcache = require('flexcache').Flexcache

backend = new RedisBackend()
fc = new Flexcache(backend, { ttl:400000 }) // 400 second timeout

slow = function(a, b, callback) { /* do something slow */ return a*b; }

cached = fc.cache(slow)

rv1 = cached(2, 3);
// next call with same arguments will return cached result
rv2 = cached(2, 3);

// edit some data
cached.clear_group(2);
// cache is not clean for all cached results in cache group 2

// whipe everything. usually not a good idea :-)
fc.clear_all()

```

Whatever arguments are passed to cached, they are used to compute the subkey and should therefor never hit a wrong
cache entry. 
    

Advanced Usage
--------------

```javascript

backend = new RedisBackend({port:1234})
fc = new Flexcache(backend, {
    group: function() { return arguments.1 },
    hash: function() { return "X" + arguments.0 },
    ttl: 60*1000,
    prefix: "grp1",
    });

// use a special key function for this function
rcached = fc.cache(slow, {
    group: function() { return self.somevalue },
    name: "somethinguniqe"
    }); 


rcached.clear(fc.get_group("my", "arguments", 2, 4, {1:3}))
```


## Flexcache Options

  - `group` *function* to generate the hash or string of *'all'*, *'one'*, *'safe_one'*, *'safe_all'*. default: **hash\_one**
  - `hash` same as hash. default: **safe\_all**
  - `ttl` timeout in seconds.
  - `group_prefix` prefix added before the group hash
  - `debug` 

## get\_group(args...)

returns the key computed as they are saved

## clear(key)

clears all caches associated with one key

typical use:

```javascript
fc.clear_group(fc.get_group(args...))
```

Usually you are better of with using the clear(...) function of the cached function as it uses the correct hasher when the cached function
uses a different hasher.

## cache(fnc, [options])

Creates a cache wrapper for a async function. Options overrides the Flexcache options.
The returned function has special members which helps you to deal with cache consistancy:

### cache Options

  - `group` *function* to generate the hash or one of *'all'*, *'one'*, *'safe_one'*, *'safe_all'*. default: **safe_all**
  - `hash` same as hash. default: **one**
  - `name` identifier for hash
  - `multi` if set, don't complain about multiple caches sharing the same name


## cache(...).clear\_group([args,...])

Clears a group. Arguments are the same as they are passed to the cache function itself, or at least, enough for the group function
to determine the group to clean. Default is the first argument.

## cache(...).clear\_hash([args,...])

Clears a specific subkey under key. If key and subkey are strings, they are used directly.
You can also pass the same arguments as the normal function and let the key and subkey be calculated by the key/hash functions.





# Backends

## RedisBackend

### Notes

  - TTL is rounded to seconds.
  - TTL only works with Redis 2.1.3+


### Options

  - `host` Redis server hostname
  - `port` Redis server portno
  - `db` Database index to use
  - `pass` Password for Redis authentication
  - ...    Remaining options passed to the redis `createClient()` method.


