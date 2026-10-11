# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "openssl"
require "uri"

module Moonraker
  module Bosun
    # Moonraker APIのクライアント
    #
    # APIの動作は docs/moonraker-api.md を参照。
    class Client
      FileInfo = Data.define(:path, :modified, :size, :permissions) do
        def writable? = permissions == "rw"
      end

      RootInfo = Data.define(:name, :path, :permissions)

      # MoonrakerがエラーのHTTPステータスを返した場合のエラー
      class APIError < Error
        attr_reader :code

        def initialize(code, message)
          @code = code
          super(Messages.t(:"client.api_error", code: code, message: message))
        end
      end

      attr_reader :base_url

      def initialize(base_url, open_timeout: 5, read_timeout: 30)
        @base_url = base_url
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      def roots
        get_json("/server/files/roots").map do |item|
          RootInfo.new(name: item.fetch("name"), path: item.fetch("path"), permissions: item.fetch("permissions"))
        end
      end

      def list_files(root)
        get_json("/server/files/list", root: root).map do |item|
          FileInfo.new(
            path: item.fetch("path"),
            modified: item.fetch("modified"),
            size: item.fetch("size"),
            permissions: item.fetch("permissions")
          )
        end
      end

      # Moonraker DBのnamespaceの一覧
      def db_namespaces
        get_json("/server/database/list").fetch("namespaces")
      rescue KeyError => e
        raise Error, Messages.t(:"client.invalid_response", context: "database/list", message: e.message)
      end

      # namespaceの内容(Hash)
      def db_namespace(namespace)
        get_json("/server/database/item", namespace: namespace).fetch("value")
      rescue KeyError => e
        raise Error, Messages.t(:"client.invalid_response", context: "database/item", message: e.message)
      end

      # print_stats.state を返す。Klipperがreadyでない場合(print_statsが空の場合)はnil
      def print_state
        get_json("/printer/objects/query", print_stats: nil).dig("status", "print_stats", "state")
      end

      # ファイルの内容をバイナリの文字列で返す
      def download(root, path)
        request(Net::HTTP::Get.new(uri(file_path(root, path)))).body.b
      end

      def delete_file(root, path)
        request(Net::HTTP::Delete.new(uri(file_path(root, path))))
        nil
      end

      # ファイルをアップロードする。同名のファイルがあれば上書きする(呼び出し側で確認すること)
      #
      # checksumにより、Moonraker側で内容が一致しなければ書き込まれない。
      def upload(root, path, content)
        dir = File.dirname(path)
        fields = [["root", root]]
        fields << ["path", dir] unless dir == "."
        fields << ["checksum", Digest::SHA256.hexdigest(content)]
        fields << ["file", content.b, { filename: File.basename(path), content_type: "application/octet-stream" }]
        req = Net::HTTP::Post.new(uri("/server/files/upload"))
        req.set_form(fields, "multipart/form-data")
        JSON.parse(request(req).body)
      rescue JSON::ParserError => e
        raise Error, Messages.t(:"client.invalid_response", context: "upload", message: e.message)
      end

      private

      def get_json(path, **query)
        response = request(Net::HTTP::Get.new(uri(path, query)))
        JSON.parse(response.body).fetch("result")
      rescue JSON::ParserError, KeyError => e
        raise Error, Messages.t(:"client.invalid_response", context: path, message: e.message)
      end

      def file_path(root, path)
        segments = [root, *path.split("/")]
        "/server/files/#{segments.map { |s| URI.encode_uri_component(s) }.join('/')}"
      end

      def uri(path, query = {})
        uri = @base_url.dup
        uri.path = @base_url.path.chomp("/") + path
        uri.query = query.empty? ? nil : URI.encode_www_form(query)
        uri
      end

      def request(req)
        response = Net::HTTP.start(
          req.uri.host, req.uri.port,
          use_ssl: req.uri.scheme == "https",
          open_timeout: @open_timeout, read_timeout: @read_timeout
        ) { |http| http.request(req) }
        raise api_error(response) unless response.is_a?(Net::HTTPSuccess)

        response
      rescue SystemCallError, SocketError, IOError, Timeout::Error,
             Net::HTTPBadResponse, Net::ProtocolError, OpenSSL::SSL::SSLError => e
        raise Error, Messages.t(:"client.connection_failed", url: @base_url, message: e.message)
      end

      # エラーの応答にはMoonraker内部のトレースバックが含まれるので、messageだけを使う
      def api_error(response)
        message = begin
          JSON.parse(response.body).dig("error", "message")
        rescue JSON::ParserError, TypeError
          nil
        end
        APIError.new(response.code.to_i, message || response.message)
      end
    end
  end
end
