require 'mysql2'

module AddrBalances

  class Parser

    attr_accessor :config, :db, :addresses

    def initialize(options)
      # Load configuration file
      puts " -- Loading configuration from file <#{options[:config]}>"
      @config = YAML::load_file(options[:config])

      # The addresses in which we are interested
      @addresses = config['addresses'].uniq.sort
      puts " -- Parsing operations for #{addresses.count} addresses"

      # Connect to the DB
      @db = Mysql2::Client.new(config['mysql'])
      puts " -- Connecting to mysql database <mysql://#{config['mysql']['username']}@#{config['mysql']['host']}:#{config['mysql']['database']}>"

      if !(%w{ addresses operations } - db.query('SHOW TABLES').map(&:values).flatten).empty?
        puts " -- Operations or addresses table does not exist, run the following script to create it and retry:\n#{get_ddl(config['mysql'])}"
        exit
      end
    end

    #
    # Returns a SQL query to insert an operation in the database
    #
    def insert_tx(address, amount, txid, block_height, block_hash)
      puts "   * Inserting #{amount.to_s('f')} BTC operation for address #{address} in block ##{block_height} (TXID: #{txid})"
      <<-EOS
      INSERT INTO operations (address, txid, amount, block_height, block_hash)
      VALUES ('#{address}', '#{txid}', #{amount.to_s('f')}, #{block_height}, #{ (block_hash && "'#{block_hash}'") || 'NULL' })
      EOS
    end

    #
    # Returns the DDL script for creating the required MySQL schema
    #
    def get_ddl(cfg)
      <<-EOS
      CREATE TABLE operations (
        id INTEGER AUTO_INCREMENT NOT NULL,
        address VARCHAR(100) NOT NULL,
        txid VARCHAR(100) NOT NULL,
        amount DECIMAL(16,8) NOT NULL,
        block_height INTEGER NOT NULL,
        block_hash VARCHAR(100) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_address` (`address`),
        KEY `idx_txid` (`txid`),
        UNIQUE KEY `idx_address_txid` (`address`, `txid`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

      CREATE TABLE addresses (
        id INTEGER AUTO_INCREMENT NOT NULL,
        address VARCHAR(255) DEFAULT NULL,
        total_received DECIMAL(16,8) DEFAULT NULL,
        balance DECIMAL(16,9) DEFAULT NULL,
        n_tx INTEGER NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_address` (`address`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
      EOS
    end

    #
    # Functionnally equivalent to `addresses.include?(addy)`, works if and
    # only if `addresses` is sorted !
    #
    def has_address?(addresses, addy)
      addy == addresses.bsearch { |a| addy <= a }
    end

    #
    # Returns a SQL query to insert address data in the database
    #
    def get_address_query(address)
      <<-EOS
      INSERT INTO addresses (address, total_received, balance, n_tx)
      VALUES ('#{address['address']}', #{(BigDecimal(address['total_received'])/(10**8)).to_s('f')}, #{(BigDecimal(address['final_balance'])/(10**8)).to_s('f')}, #{address['n_tx']});
      EOS
    end

  end
end


