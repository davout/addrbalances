require 'addrbalances/bitcoin_client'

module AddrBalances

  class Bitcoind < Parser

    attr_accessor :n_blocks, :skip_blocks, :bitcoin

    def initialize(options)
      super

      @tx_cache = {}

      # Whether we want to skip blocks (useful if we know transactions start only at a certain height)
      @skip_blocks = options[:skip_blocks] || 0
      puts " -- Skipping #{skip_blocks} blocks before parsing, starting at height #{skip_blocks + 1}"

      # Whether we limit the total numbers of blocks to parse
      @n_blocks = options[:n_blocks]

      if n_blocks
        puts " -- Parsing only #{n_blocks} blocks"
      else
        puts " -- No limit on the number of parsed blocks"
      end

      # Connecting to Bitcoin client
      @bitcoin = BitcoinClient.new(config['bitcoind']['uri'], config['bitcoind']['username'], config['bitcoind']['password'])
      puts " -- Connected to Bitcoin client, #{bitcoin.getinfo['blocks']} blocks downloaded"
    end

    #
    # Parses the blockchain for operations relevant to a given set of addresses
    #
    def run!
      start = skip_blocks + 1
      finish = n_blocks ? start + (n_blocks - 1): bitcoin.getinfo['blocks'].to_i
      puts " -- Starting blockchain exploration of blocks #{start} to #{finish}, make yourself comfortable..."

      n_processed = 0
      total_processing_time ||= 0

      # For each block
      (start..finish).each do |i|
        @cache_hit = 0
        @cache_miss = 0

      start_time = Time.now.to_f

        blk = bitcoin.get_block(bitcoin.get_block_hash(i))

        # For each transaction inside this block
        blk['tx'].map { |txid| get_tx(txid) }.each do |tx|
          idxs_with_data = []
          funds_from = []
          funds_to = []

          # Look into each input to see if send funds from an address we're interested in
          tx['vin'].each do |vin|
            unless vin['coinbase']
              input = get_tx(vin['txid'])['vout'][vin['vout']]
              addy = input['scriptPubKey'] && input['scriptPubKey']['addresses'].first

              if addy && has_address?(addresses, addy)
                addr_idx = addresses.index(addy)
                funds_from[addr_idx] ||= 0
                funds_from[addr_idx] += input['value']
                idxs_with_data << addr_idx
              end
            end
          end

          # Look into each out to see if we're paying any of the addresses we're interested in
          tx['vout'].each do |out|
            addy = out['scriptPubKey'] && out['scriptPubKey']['addresses'] && (out['scriptPubKey']['addresses'].first)

            if addy && has_address?(addresses, addy)
              addr_idx = addresses.index(addy)
              funds_to[addr_idx] ||= 0
              funds_to[addr_idx] += out['value']
              idxs_with_data << addr_idx
            end
          end

          idxs_with_data.uniq.each do |idx|
            addy = addresses[idx]
            net_change = (funds_to[idx] || 0) - (funds_from[idx] || 0)

            unless net_change.zero?
              db.query(insert_tx(addy, net_change, tx['txid'], i, blk['hash']))
            end
          end
        end

        end_time = Time.now.to_f

        n_processed += 1
        total_processing_time += end_time - start_time
        eta = (finish - i) * (total_processing_time.to_f / n_processed)
        elapsed = end_time - start_time

        puts "[#{'%.2f' % (((i - start).to_f * 100) / (finish - start))}%] Block ##{i} <#{blk['hash']}> (#{'%.2f' % elapsed}s, ETA: #{"%.3f" % (eta / 3600)} hours), cache efficiency: #{'%.2f' % ((@cache_hit.to_f * 100)/(@cache_hit+@cache_miss))}%, processing speed: #{'%.2f' % ((blk['size'].to_f / (1024 * 1024)) / elapsed)} mb/s"
      end
    end

    #
    # Cached transaction data
    #
    def get_tx(txid)
      if @tx_cache[txid]
        @cache_hit += 1
        @tx_cache[txid]
      else
        @cache_miss += 1
        @tx_cache[txid] = bitcoin.get_raw_transaction(txid, 1)
      end
    end

  end
end


