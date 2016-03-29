require 'net/http'
require 'addressable/uri'
require 'oj'

module AddrBalances
  class BitcoinClient

    def initialize(url, username, password)
      @address = Addressable::URI.parse(url)
      @username = username
      @password = password
    end

    def request(params)
      result = nil

      full_params = params.merge({
        jsonrpc:  '2.0',
        id:       (rand * 10 ** 12).to_i.to_s
      })

      request_body = Oj.dump(full_params, mode: :compat)

      begin
        tries ||= 3

        Net::HTTP.start(@address.host, @address.port) do |connection|
          post = Net::HTTP::Post.new(@address.path)
          post.body = request_body
          post.basic_auth(@username, @password)
          result = connection.request(post)
          result = Oj.load(result.body, bigdecimal_load: true)
        end
      rescue
        tries -= 1
        if tries > 0
          sleep(3)
          puts "  ## Retrying after exception: #{$!.message}"
          retry
        else
          puts "  ## Too many retries! Aborting."
          raise
        end
      end

      if error = result["error"]
        puts result
        raise "#{error["message"]}, request was #{request_body}"
      end

      result = result["result"]
      result
    end

    def method_missing(method, *args)
      request({
        method: method.to_s.gsub(/\_/, ""),
        params: args
      })
    end

  end
end

