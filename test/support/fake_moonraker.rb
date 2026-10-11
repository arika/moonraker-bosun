# frozen_string_literal: true

# テスト用のメモリ上のMoonraker
class FakeMoonraker
  Entry = Struct.new(:content, :permissions, :modified)

  def initialize
    @roots = Hash.new { |hash, key| hash[key] = {} }
  end

  attr_accessor :print_state

  def db = @db ||= {}
  def db_namespaces = db.keys

  def db_namespace(namespace)
    raise Moonraker::Bosun::Client::APIError.new(404, "Namespace #{namespace} not found") unless db.key?(namespace)

    db[namespace]
  end
  attr_writer :root_infos

  def roots
    @root_infos || []
  end

  def put(root, path, content, permissions: "rw", modified: 1_790_000_000.5)
    @roots[root][path] = Entry.new(content.b, permissions, modified)
  end

  def list_files(root)
    result = @roots[root].map do |path, entry|
      Moonraker::Bosun::Client::FileInfo.new(path: path, modified: entry.modified,
                                             size: entry.content.bytesize, permissions: entry.permissions)
    end
    after_list&.call(root)
    result
  end

  # テストで、操作の前後に呼ばれる処理(失敗させる、ホストを変更するなど)
  attr_accessor :before_upload, :after_list, :after_download

  def uploads = @uploads ||= []

  def upload(root, path, content)
    before_upload&.call(root, path)
    uploads << [root, path]
    entry = @roots[root][path]
    modified = (entry&.modified || 1_790_000_000.0) + 1000
    put(root, path, content, modified: modified, permissions: entry&.permissions || "rw")
    { "action" => "create_file" }
  end

  def downloads = @downloads ||= []

  def delete_file(root, path)
    raise Moonraker::Bosun::Client::APIError.new(400, "Bad Request") unless @roots[root].key?(path)

    delete(root, path)
  end

  def delete(root, path)
    @roots[root].delete(path)
  end

  def download(root, path)
    downloads << [root, path]
    entry = @roots[root][path]
    raise Moonraker::Bosun::Client::APIError.new(404, "Not Found") unless entry

    content = entry.content.dup
    after_download&.call(root, path)
    content
  end
end
