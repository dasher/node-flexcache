{ Backend } = require './base'
redis = require 'redis'
buffalo = require 'buffalo'
async = require 'async'
quack = require 'quack-array'


class RedisBackend extends Backend
    constructor: (options) ->
        @options = options or {}
        @options.return_buffers = true
        @client = new redis.createClient(@options.port or @options.socket, @options.host, @options)
        @ttl_bug = false

        super @options

        if @options.pass
            @client.auth @options.pass, (err) ->
                throw err if err

        if @options.db
            @client.select(@options.db)
            @client.on "connect", () =>
                @client.send_anyways = true
                @client.select options.db
                @client.send_anyways = false

        @client.on "connect", () =>
            @client.info (err, res) =>
                res = res.toString()
                for line in res.split("\r\n")
                    [key, value] = line.split(":")
                    if key == 'redis_version'
                        vers = value.split(".")
                        if Number(vers[0]) <= 2 and Number(vers[1]) <= 1 and Number(vers[2]) < 3
                            @ttl_bug = true
                            console.log("!!!! WARNING !!!!", "redis version needs to be 2.1.3+ for correct behaviour. TTL will not work" )
                        else
                            @ttl_buf = false


        
    get: (key, subkey, fn) =>
        this.client.hget key, subkey, (err, data) =>
            if err or not data
                return fn(err, null)
            try
                x = buffalo.parse(new Buffer(data))
                decoded = quack(buffalo.parse(new Buffer(data)))
            catch e
                console.log("err decoding blob" + e)
                decoded = null
            if not decoded
                return fn()
            fn null, decoded

    set: (key, subkey, ttl, data, fn) =>
        fn = fn
        try
            if ttl == -1
                rttl = -1
            else
                rttl = ttl/1000 or 6*60*60
            rdata = buffalo.serialize(data)
            async.waterfall [
                (next) =>
                    @client.ttl key, (err, res) =>
                        next(null, res > 0 and res or rttl)
                ,
                (oldttl, next) =>
                    @client.hset key, subkey, rdata, (err, res) ->
                        next(err, oldttl, res)
                ,
                (oldttl, res, next) =>
                    if @ttl_bug
                        return next(null, null)
                    @client.expire key, oldttl, (err, res) ->
                        next(null, null)

            ], (err) ->
                if not fn
                    return
                fn err, data
        catch err
            fn and fn(err, null)

    clear: (key, fn) =>
        @client.del key, (err, res) ->
            fn and fn(null, null)

    clear_subkey: (key, subkey, fn) =>
        @client.hdel key, subkey, (err, res) ->
            fn(null, null)

    dbsize: (fn) =>
        @client.dbsize(fn)

    clear_all: (fn) =>
        @client.flushdb(fn)

    close: (fn) =>
        @client.quit(fn)

module.exports = { RedisBackend }
