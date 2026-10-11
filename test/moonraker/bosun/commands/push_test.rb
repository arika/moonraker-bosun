# frozen_string_literal: true

require "test_helper"

class PushCommandTest < Minitest::Test
  include CommandTestHelper
  include GitRepoHelper

  def setup
    super
    @moonraker.put("config", "printer.cfg", "[printer]\nmax_velocity: 300\n")
    @moonraker.put("config", "moonraker.conf", "[server]\n")
    assert_equal 0, bosun("add", "printer.cfg", "moonraker.conf"), @err.string
    @out.truncate(0)
    @out.rewind
  end

  def commit_local(path, content)
    write("config/#{path}", content)
    git("add", "config/#{path}")
    git("commit", "-q", "-m", "local #{path}")
  end

  def host(path) = @moonraker.download("config", path)

  def test_push_updates_and_creates
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    commit_local("macros/start.cfg", "[gcode_macro START]\n")
    parent = tracking_tip

    assert_equal 0, bosun("push"), @err.string
    assert_equal "[printer]\nmax_velocity: 250\n", host("printer.cfg")
    assert_equal "[gcode_macro START]\n", host("macros/start.cfg")
    assert_equal [%w[config macros/start.cfg], %w[config printer.cfg]], @moonraker.uploads

    # 取得し直してhost-trackingにコミットし、マージする
    assert_equal [parent], parents(Moonraker::Bosun::HostTracking::REF)
    assert_equal "push: 2 files", tracking_messages.first.lines.first.chomp
    assert_includes tracking_messages.first, "Host-Op: push\n"
    assert git("merge-base", "--is-ancestor", tracking_tip, "main")
    assert_empty git("diff", Moonraker::Bosun::HostTracking::BRANCH, "main", "--", "config")
    assert_includes @out.string, "アップロードしました: macros/start.cfg\nアップロードしました: printer.cfg\n"
    assert_match(/RESTART/, @out.string)
  end

  def test_status_is_synced_after_push
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    assert_equal 0, bosun("push"), @err.string
    @out.truncate(0)
    @out.rewind

    assert_equal 0, bosun("audit"), @out.string
  end

  def test_push_does_not_write_when_plan_has_problem
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    commit_local("moonraker.conf", "[server]\nlocal\n")
    @moonraker.put("config", "moonraker.conf", "[server]\nhost\n", modified: 1_790_000_500.0)

    assert_equal 1, bosun("push")
    assert_empty @moonraker.uploads
    assert_equal "[printer]\nmax_velocity: 300\n", host("printer.cfg")
  end

  def test_push_aborts_when_host_changes_after_plan
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    # 計画で内容を確認した後(書き込む直前の一覧を取得する前)に、ホストで変更されたことにする
    @moonraker.after_download = lambda do |_root, path|
      @moonraker.put("config", "printer.cfg", "[printer]\nhost\n", modified: 1_790_000_500.0) if path == "printer.cfg"
      @moonraker.after_download = nil
    end

    assert_equal 1, bosun("push")
    assert_match(/確認の後にホストでファイルが変わったため、中止しました.*printer.cfg/, @err.string)
    assert_empty @moonraker.uploads
  end

  def test_push_aborts_when_file_is_created_on_host_after_plan
    commit_local("macros.cfg", "[gcode_macro A]\n")
    lists = 0
    @moonraker.after_list = lambda do |_root|
      lists += 1
      @moonraker.put("config", "macros.cfg", "[gcode_macro B]\n") if lists == 1
    end

    assert_equal 1, bosun("push")
    assert_match(/確認の後にホストでファイルが変わったため/, @err.string)
    assert_equal "[gcode_macro B]\n", host("macros.cfg")
  end

  def test_push_records_uploaded_files_when_upload_fails_midway
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    commit_local("moonraker.conf", "[server]\nlocal\n")
    @moonraker.before_upload = lambda do |_root, path|
      raise Moonraker::Bosun::Client::APIError.new(500, "Internal Server Error") if path == "printer.cfg"
    end

    assert_equal 1, bosun("push")
    assert_match(/アップロードの途中で失敗しました。反映していないファイル: printer.cfg/, @err.string)
    # 反映できたmoonraker.confは記録されている
    assert_equal "[server]\nlocal\n", show("#{Moonraker::Bosun::HostTracking::REF}:config/moonraker.conf")
    assert_equal "[printer]\nmax_velocity: 300\n", show("#{Moonraker::Bosun::HostTracking::REF}:config/printer.cfg")

    @moonraker.before_upload = nil
    @out.truncate(0)
    @out.rewind
    assert_equal 0, bosun("push", "-n")
    assert_includes @out.string, "更新: printer.cfg\n"
    refute_includes @out.string, "moonraker.conf"
  end

  def test_push_does_not_upload_symlink
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    File.symlink("printer.cfg", File.join(@cwd, "config/link.cfg"))
    git("add", "config/link.cfg")
    git("commit", "-q", "-m", "link")

    assert_equal 1, bosun("push")
    assert_empty @moonraker.uploads
  end

  def test_push_records_uploaded_files_when_interrupted
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    commit_local("moonraker.conf", "[server]\nlocal\n")
    @moonraker.before_upload = ->(_root, path) { raise Interrupt if path == "printer.cfg" }

    assert_equal 130, bosun("push")
    assert_match(/アップロードの途中で失敗しました。反映していないファイル: printer.cfg/, @err.string)
    assert_match(/中断しました/, @err.string)
    assert_equal "[server]\nlocal\n", show("#{Moonraker::Bosun::HostTracking::REF}:config/moonraker.conf")
  end

  def test_push_records_host_content_even_if_different
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    # アップロードした直後に、ホストで書き換えられたことにする
    @moonraker.before_upload = nil
    original_upload = @moonraker.method(:upload)
    @moonraker.define_singleton_method(:upload) do |root, path, content|
      original_upload.call(root, path, content)
      put(root, path, "[printer]\nrewritten\n", modified: 1_790_009_999.0)
    end

    # host-trackingにはホストの内容を記録するので、ローカルの内容とのマージで衝突する
    assert_equal 1, bosun("push")
    assert_match(/警告: ホストの内容が反映した内容と違います/, @err.string)
    assert_match(/マージで衝突しました/, @err.string)
    assert_equal "[printer]\nrewritten\n", show("#{Moonraker::Bosun::HostTracking::REF}:config/printer.cfg")
  end

  def test_push_aborts_while_printing
    commit_local("printer.cfg", "[printer]\nmax_velocity: 250\n")
    @moonraker.print_state = "printing"

    assert_equal 1, bosun("push")
    assert_empty @moonraker.uploads
  end

  def test_push_nothing
    assert_equal 0, bosun("push")
    assert_equal "反映する変更はありません\n", @out.string
    assert_empty @moonraker.uploads
  end
end
