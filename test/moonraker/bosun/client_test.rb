# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  def teardown
    @stub&.close
  end

  def client(base_url = @stub.url)
    Moonraker::Bosun::Client.new(URI.parse(base_url), open_timeout: 1, read_timeout: 1)
  end

  def json_response(value, status: 200)
    [status, { "Content-Type" => "application/json" }, JSON.generate(value)]
  end

  def test_list_files
    @stub = HTTPStub.new do
      json_response({ "result" => [
                      { "path" => "printer.cfg", "modified" => 1_791_695_466.5512717, "size" => 2767,
                        "permissions" => "rw" },
                      { "path" => "mainsail.cfg", "modified" => 1_778_097_506.7109838, "size" => 16_493,
                        "permissions" => "r" }
                    ] })
    end
    files = client.list_files("config")

    assert_equal "/server/files/list?root=config", @stub.requests.last.target
    assert_equal ["printer.cfg", "mainsail.cfg"], files.map(&:path)
    assert_in_delta(1_791_695_466.5512717, files.first.modified)
    assert_equal 2767, files.first.size
    assert_predicate files.first, :writable?
    refute_predicate files.last, :writable?
  end

  def test_roots
    @stub = HTTPStub.new do
      json_response({ "result" => [
                      { "name" => "config", "path" => "/home/a/printer_data/config", "permissions" => "rw" },
                      { "name" => "logs", "path" => "/home/a/printer_data/logs", "permissions" => "r" }
                    ] })
    end
    roots = client.roots

    assert_equal "/server/files/roots", @stub.requests.last.target
    assert_equal %w[config logs], roots.map(&:name)
    assert_equal "/home/a/printer_data/config", roots.first.path
    assert_equal "r", roots.last.permissions
  end

  def test_print_state
    @stub = HTTPStub.new do
      json_response({ "result" => { "eventtime" => 1.0, "status" => { "print_stats" => { "state" => "printing" } } } })
    end
    assert_equal "printing", client.print_state
    assert_equal "/printer/objects/query?print_stats", @stub.requests.last.target
  end

  def test_print_state_when_klipper_is_not_ready
    @stub = HTTPStub.new { json_response({ "result" => { "eventtime" => 1.0, "status" => { "print_stats" => {} } } }) }
    assert_nil client.print_state
  end

  def test_upload
    @stub = HTTPStub.new { json_response({ "item" => { "path" => "macros/start.cfg" }, "action" => "create_file" }) }
    content = "[gcode_macro START]\n\xE3\x81\x82".b
    result = client.upload("config", "macros/start.cfg", content)
    request = @stub.requests.last

    assert_equal "create_file", result["action"]
    assert_equal "POST", request.request_method
    assert_equal "/server/files/upload", request.target
    assert_match(%r{\Amultipart/form-data; boundary=}, request.headers["content-type"])
    form = request.form
    assert_equal %w[checksum file path root], form.keys.sort
    assert_equal "config", form["root"]
    assert_equal "macros", form["path"]
    assert_equal Digest::SHA256.hexdigest(content), form["checksum"]
    assert_equal "start.cfg", form["file"].filename
    assert_equal content, form["file"].b
  end

  def test_upload_to_root_directory_omits_path
    @stub = HTTPStub.new { json_response({ "action" => "create_file" }) }
    client.upload("config", "printer.cfg", "x")
    refute_includes @stub.requests.last.form.keys, "path"
  end

  def test_delete_file
    @stub = HTTPStub.new { json_response({ "result" => { "action" => "delete_file" } }) }
    client.delete_file("config", "macros/a b.cfg")
    assert_equal "DELETE", @stub.requests.last.request_method
    assert_equal "/server/files/config/macros/a%20b.cfg", @stub.requests.last.target
  end

  def test_db_namespaces_and_item
    @stub = HTTPStub.new do |request|
      if request.target.start_with?("/server/database/list")
        json_response({ "result" => { "namespaces" => %w[mainsail moonraker], "backups" => [] } })
      else
        json_response({ "result" => { "namespace" => "mainsail", "key" => nil, "value" => { "general" => {} } } })
      end
    end
    assert_equal %w[mainsail moonraker], client.db_namespaces
    assert_equal({ "general" => {} }, client.db_namespace("mainsail"))
    assert_equal "/server/database/item?namespace=mainsail", @stub.requests.last.target
  end

  def test_download
    @stub = HTTPStub.new { [200, { "Content-Type" => "text/plain" }, "[printer]\n\xE3\x81\x82\n".b] }
    body = client.download("config", "printer.cfg")

    assert_equal "/server/files/config/printer.cfg", @stub.requests.last.target
    assert_equal Encoding::BINARY, body.encoding
    assert_equal "[printer]\n\xE3\x81\x82\n".b, body
  end

  def test_download_encodes_path_segments
    @stub = HTTPStub.new { [200, {}, ""] }
    client.download("config", "macros/my macro#1.cfg")

    assert_equal "/server/files/config/macros/my%20macro%231.cfg", @stub.requests.last.target
  end

  def test_base_url_with_path_prefix
    @stub = HTTPStub.new { json_response({ "result" => [] }) }
    client("#{@stub.url}/moonraker/").list_files("logs")

    assert_equal "/moonraker/server/files/list?root=logs", @stub.requests.last.target
  end

  def test_api_error_uses_message_without_traceback
    @stub = HTTPStub.new do
      json_response({ "error" => { "code" => 404, "message" => "Not Found", "traceback" => "Traceback ..." } },
                    status: 404)
    end
    error = assert_raises(Moonraker::Bosun::Client::APIError) { client.download("config", "nosuch.cfg") }

    assert_equal 404, error.code
    assert_match(/Not Found/, error.message)
    refute_match(/Traceback/, error.message)
  end

  def test_api_error_without_json_body
    @stub = HTTPStub.new { [502, {}, "<html>Bad Gateway</html>"] }
    error = assert_raises(Moonraker::Bosun::Client::APIError) { client.list_files("config") }

    assert_equal 502, error.code
  end

  def test_invalid_json
    @stub = HTTPStub.new { [200, {}, "not json"] }
    error = assert_raises(Moonraker::Bosun::Error) { client.list_files("config") }

    assert_match(/cannot parse the response from Moonraker/, error.message)
  end

  def test_bad_response
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      socket = server.accept
      socket.gets
      socket.write("NOT HTTP\r\n\r\n")
      socket.close
    end
    error = assert_raises(Moonraker::Bosun::Error) { client("http://127.0.0.1:#{server.addr[1]}").list_files("config") }

    assert_match(/cannot connect to Moonraker/, error.message)
  ensure
    thread&.join
    server&.close
  end

  def test_connection_refused
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    error = assert_raises(Moonraker::Bosun::Error) { client("http://127.0.0.1:#{port}").list_files("config") }

    assert_match(/cannot connect to Moonraker/, error.message)
  end
end
