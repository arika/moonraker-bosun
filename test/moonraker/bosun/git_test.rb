# frozen_string_literal: true

require "test_helper"

class GitTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @git = Moonraker::Bosun::Git.new(@cwd)
  end

  def test_open_from_subdirectory
    FileUtils.mkdir_p(File.join(@cwd, "lib/deep"))
    assert_equal File.realpath(@cwd), File.realpath(Moonraker::Bosun::Git.open(File.join(@cwd, "lib/deep")).root)
  end

  def test_rev_parse
    assert_equal rev("HEAD"), @git.rev_parse("HEAD")
    assert_nil @git.rev_parse("refs/heads/nosuch")
  end

  def test_dirty_paths
    write("lib/bosun.rb", "# changed\n")
    write("config/new file.cfg", "new\n")
    write("README.md", "staged\n")
    git("add", "README.md")
    git("mv", "lib/bosun.rb", "lib/moved.rb")

    assert_equal ["config/new file.cfg"], @git.dirty_paths(["config/new file.cfg"])
    assert_equal ["README.md"], @git.dirty_paths(["README.md"])
    assert_includes @git.dirty_paths(["lib"]), "lib/bosun.rb"
    assert_empty @git.dirty_paths(["config/other.cfg"])
    assert_empty @git.dirty_paths([])
  end

  def test_literal_pathspecs
    write("config/*.cfg", "star\n")
    write("config/a.cfg", "a\n")
    assert_equal ["config/*.cfg"], @git.dirty_paths(["config/*.cfg"])
  end

  def test_hash_object_without_filters
    write(".gitattributes", "* text eol=lf\n")
    blob = @git.hash_object("a\r\nb\r\n")
    assert_equal "a\r\nb\r\n", git("cat-file", "blob", blob)
  end
end
