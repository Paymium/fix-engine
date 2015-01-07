FIX Engine [![Build Status](https://secure.travis-ci.org/Paymium/fix-engine.png?branch=master)](http://travis-ci.org/Paymium/fix-engine)
=

This library provides an event-machine based FIX server and client connection implementation.

# Usage example (client connection)

## Connection class

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

## Connecting it to a FIX server

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

# Usage example (FIX acceptor)

TODO
