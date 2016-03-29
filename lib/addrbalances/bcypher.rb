require 'blockcypher'

module AddrBalances

  class BCypher < Parser

    attr_accessor :bcypher

    def initialize(options)
      super
      @bcypher = BlockCypher::Api.new(api_token: 'b9c88fa62c0e4f6a6784dd2fa7845ed1')
    end

    #
    # Parses the blockchain for operations relevant to a given set of addresses
    #
    def run!
      cnt = addresses.size

      addresses.each_slice(1) do |addies|
        before  = nil
        get_txrefs_batched(addies).each do |tr|
          addy = tr['address']
          txrefs  = [tr['txrefs']]

          # Insert global address meta-data
          db.query(get_address_query(tr))

          while tr['hasMore']
            puts "Address #{addy} has more transactions, fetching moar before block #{txrefs.last.last['block_height']}"
            sleep(19)
            tr = get_txrefs(addy, txrefs.last.last['block_height'])
            txrefs << tr['txrefs']
          end

          txs     = Hash.new { 0 }
          blocks  = {}

          txrefs.flatten.each do |t|
            m = t['spent'] ? -1 : 1
            txs[t['tx_hash']] += m * BigDecimal(t['value']) / (10 ** 8)
            blocks[t['tx_hash']] ||= t['block_height']
          end

          txs.each do |txid, amt|
            db.query(insert_tx(addy, amt, txid, blocks[txid], nil))
          end

          sleep(19)
        end
      end
    end

    #
    # Get batched address txrefs from blockcypher API
    #
    def get_txrefs_batched(addies, limit = 100)
      bcypher.address_details(addies.join(';'), limit: 100)
    end

    #
    # Get address txrefs from blockcypher API
    #
    def get_txrefs(addy, before = nil, limit = 100)
      bcypher.address_details(addy, before: before, limit: 100)
    end

  end
end

