# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "moonraker/bosun"
require "minitest/autorun"
require "open3"
require "stringio"
require "tmpdir"
require_relative "support/http_stub"
require_relative "support/fake_moonraker"

# gitコマンドの実行に時間がかかるので、テストを並列に実行する
Minitest::Test.parallelize_me!

module CommandTestHelper
  def setup
    super
    @out = StringIO.new
    @err = StringIO.new
    @moonraker = FakeMoonraker.new
    @cwd = Dir.mktmpdir("bosun-test")
  end

  def teardown
    FileUtils.remove_entry(@cwd)
    super
  end

  # 既存のテストは日本語のメッセージで確かめる
  def bosun(*argv, env: { "LANG" => "ja_JP.UTF-8" })
    Moonraker::Bosun::CLI.new(out: @out, err: @err, env: env, cwd: @cwd, client: @moonraker).run(argv)
  end
end

# 一時ディレクトリに作ったgitリポジトリでテストする
module GitRepoHelper
  GIT_ENV = {
    "GIT_CONFIG_GLOBAL" => File::NULL,
    "GIT_CONFIG_NOSYSTEM" => "1",
    "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
    "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"
  }.freeze

  # テストを並列に実行するので、テストごとに設定し直さず、最初に一度だけ設定する
  ENV.update(GIT_ENV)

  def setup
    super
    git("init", "-q", "-b", "main")
    write("README.md", "# test\n")
    write("lib/bosun.rb", "# code\n")
    git("add", ".")
    git("commit", "-q", "-m", "initial")
  end

  def git(*args)
    stdout, stderr, status = Open3.capture3("git", "-C", @cwd, *args)
    raise "git #{args.join(' ')} failed: #{stderr}" unless status.success?

    stdout
  end

  def write(path, content)
    full = File.join(@cwd, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.binwrite(full, content)
  end

  def read(path) = File.binread(File.join(@cwd, path))
  def rev(ref) = git("rev-parse", ref).strip
  def show(spec) = git("show", spec)
  def tracking_tip = rev(Moonraker::Bosun::HostTracking::REF)
  def tree_paths(ref) = git("ls-tree", "-r", "--name-only", ref).lines(chomp: true)
  def parents(ref) = git("log", "-1", "--format=%P", ref).split
  def tracking_messages = git("log", "--format=%B%x00", Moonraker::Bosun::HostTracking::REF).split("\0").map(&:strip)
end
