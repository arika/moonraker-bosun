# frozen_string_literal: true

require "test_helper"
require "rbconfig"
require "bundled_gems"

# 実行時の依存がdefault gem(とgemになっていない標準ライブラリ)だけであることを確かめる
#
# gemspecには実行時の依存を書かないので、bundled gemを使うと、Bundlerの下などでrequireできなくなる。
# Rubyの対応バージョンを上げたときに、default gemからbundled gemに移ったものを検出する。
class DependenciesTest < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)
  LIBRARY_DIRS = RbConfig::CONFIG.values_at("rubylibdir", "rubyarchdir").freeze
  EXTENSIONS = %w[.rb .so .bundle .dll].freeze

  def required_libraries
    files = Dir["#{ROOT}/{lib,exe}/**/*"].select { |path| File.file?(path) }
    libraries = files.flat_map { |path| File.read(path).scan(/^\s*require "([^"]+)"/).flatten }
    libraries.uniq.reject { |library| library.start_with?("moonraker/") }.sort
  end

  # default gemとgemになっていない標準ライブラリは、Rubyのライブラリのディレクトリにある
  # (bundled gemはgemのディレクトリにインストールされる)
  def shipped_with_ruby?(library)
    LIBRARY_DIRS.product(EXTENSIONS).any? { |dir, ext| File.exist?(File.join(dir, "#{library}#{ext}")) }
  end

  def test_required_libraries_are_found
    assert_includes required_libraries, "net/http"
  end

  def test_runtime_dependencies_are_default_gems
    required_libraries.each do |library|
      assert shipped_with_ruby?(library), "#{library}はRubyの標準ライブラリ(default gem)ではありません"
    end
  end

  # まだdefault gemでも、bundled gemに移ることが決まっているものは使わない
  def test_runtime_dependencies_are_not_becoming_bundled_gems
    required_libraries.each do |library|
      [library, library.tr("/", "-")].each do |name|
        since = Gem::BUNDLED_GEMS::SINCE[name]
        refute since, "#{library}はRuby #{since}からbundled gemになります"
      end
    end
  end
end
