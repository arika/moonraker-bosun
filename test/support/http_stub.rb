# frozen_string_literal: true

require "webrick"

# テスト用のHTTPサーバー
#
# 受け取ったリクエストをブロックに渡し、[ステータス, ヘッダ, 本文]を返させる。
# テストごとに別のサーバーを起動するので、並列に実行しても互いに影響しない。
class HTTPStub
  # formは、multipart/form-dataの場合に、フィールド名から値(WEBrick::HTTPUtils::FormData)へのHash
  Request = Data.define(:request_method, :target, :headers, :body, :form)

  # メソッドに関わらず、すべてのリクエストをHTTPStubに渡す
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, stub)
      super
      @stub = stub
    end

    def service(request, response) = @stub.handle(request, response)
  end

  attr_reader :requests

  def initialize(&handler)
    @handler = handler
    @requests = []
    started = Thread::Queue.new
    @server = WEBrick::HTTPServer.new(
      BindAddress: "127.0.0.1", Port: 0,
      Logger: WEBrick::Log.new(File::NULL), AccessLog: [],
      StartCallback: -> { started << true }
    )
    @server.mount("/", Servlet, self)
    @thread = Thread.new { @server.start }
    started.pop
  end

  def url = "http://127.0.0.1:#{port}"
  def port = @server.listeners.first.addr[1]

  def close
    @server.shutdown
    @thread.join
  end

  def handle(request, response)
    multipart = request.content_type&.start_with?("multipart/form-data")
    @requests << Request.new(
      request_method: request.request_method,
      target: request.unparsed_uri,
      headers: request.header.transform_values { |values| values.join(", ") },
      body: request.body,
      form: multipart ? request.query : {}
    )

    status, headers, body = begin
      @handler.call(@requests.last)
    rescue StandardError => e
      [500, {}, "#{e.class}: #{e.message}"]
    end
    response.status = status
    headers.each { |key, value| response[key] = value }
    response.body = body.b
  end
end
