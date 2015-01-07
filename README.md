FIX Engine [![Build Status](https://secure.travis-ci.org/Paymium/fix-engine.png?branch=master)](http://travis-ci.org/Paymium/fix-engine)
=

This library provides an event-machine based FIX server and client connection implementation.

# Usage as a FIX client

## Implement a connection handler

Create an `EM::Connection` subclass and include the `FE::ClientConnection` module. You will then have to implement
the callbacks for the various message types you are interested in.

````ruby
require 'fix/engine'

module Referee

  class FixConnection < EM::Connection

    include FE::ClientConnection

    attr_accessor :exchange

    #
    # When a logon message is received we request a market snapshot
    # and subscribe for continuous updates
    #
    def on_logon(msg)
      mdr = FP::Messages::MarketDataRequest.new

      mdr.md_req_id = 'foo'

      mdr.subscription_request_type = :updates
      mdr.market_depth              = :full
      mdr.md_update_type            = :incremental

      mdr.instruments.build do |i|
        i.symbol = 'EUR/XBT'
      end

      [:bid, :ask, :trade, :open, :vwap, :close].each do |mdet|
        mdr.md_entry_types.build do |m|
          m.md_entry_type = mdet
        end
      end

      send_msg(mdr)
    end

    # Called when a market data snapshot is received
    def on_market_data_snapshot(msg)
      update_book_with(msg)
    end

    # Called upon each subsequent update
    def on_market_data_incremental_refresh(msg)
      update_book_with(msg)
    end

    # Update the local order book copy with the new data
    def update_book_with(msg)
      msg.md_entries.each do |mde|
        exchange.book[mde.md_entry_type].set_depth_at(BigDecimal(mde.md_entry_px), BigDecimal(mde.md_entry_size))
      end
    end

  end
end
````

## Use it to connect to a FIX acceptor

Once your connection class has been created you can establish a connection in a running EventMachine reactor. 
See the [referee gem](https://github.com/davout/referee) for the full code example.

````ruby
require 'referee/exchange'
require 'referee/fix_connection'

module Referee
  module Exchanges
    class Paymium < Referee::Exchange

      FIX_SERVER  = 'fix.paymium.com'
      FIX_PORT    = 8359

      def symbol
        'PAYM'
      end

      def currency
        'EUR'
      end

      def connect
        FE::Logger.logger.level = Logger::WARN

        EM.connect(FIX_SERVER, FIX_PORT, FixConnection) do |conn|
          conn.target_comp_id = 'PAYMIUM'
          conn.comp_id        = 'BC-U458625'
          conn.username       = 'BC-U458625'
          conn.exchange       = self
        end
      end
    end
  end
end
````


# Usage as a FIX acceptor

You can start a simple FIX acceptor that will maintain a session by running the `fix-engine` executable.
The basic FIX acceptor requires a `COMP_ID` environment variable to be set.

````
$ COMP_ID=MY_COMP_ID fix-engine

> D, [2015-01-07T12:47:07.807867 #87486] DEBUG -- : Starting FIX engine v0.0.31, listening on <0.0.0.0:8359>, exit with <Ctrl-C>
> D, [2015-01-07T12:47:12.379787 #87486] DEBUG -- : Client connected <127.0.0.1:54204>, expecting logon message in the next 10s
> D, [2015-01-07T12:47:12.816626 #87486] DEBUG -- : Received a <Fix::Protocol::Messages::Logon> from <127.0.0.1:54204> with sequence number <1>
> D, [2015-01-07T12:47:12.820093 #87486] DEBUG -- : Peer authenticated as <JAVA_TESTS> with heartbeat interval of <30s> and message sequence number start <1>
> D, [2015-01-07T12:47:12.820259 #87486] DEBUG -- : Heartbeat interval for <127.0.0.1:54204> : <30s>
> D, [2015-01-07T12:47:12.820899 #87486] DEBUG -- : Sending <Fix::Protocol::Messages::Logon> to <127.0.0.1:54204> with sequence number <1>
````

In order to handle business messages appropriately you need to implement a connection handler
that includes the `FE::ServerConnection` module and use that as a connection handler.

````ruby
class MyHandler < EM::Connection

  include FE::ServerConnection

  def on_market_data_request
    # Fetch market data and send the relevant response
    #  ...
  end

end

server = FE::Server.new('127.0.0.1', 8095, MyHandler) do |conn|
  conn.comp_id = 'MY_COMP_ID'
end

# This will also start an EventMachine reactor
server.run!

# This would be used inside an already-running reactor
EM.run do
  server.start_server
end
````

