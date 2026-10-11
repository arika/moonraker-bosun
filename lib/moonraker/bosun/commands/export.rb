# frozen_string_literal: true

require "fileutils"
require "time"

module Moonraker
  module Bosun
    module Commands
      class Export < Base
        def run(args)
          at = nil
          rev = nil
          output = nil
          args = parse_options(args) do |o|
            o.on("--at DATETIME", t(:"export.at_option")) { |v| at = v }
            o.on("--rev REV", t(:"export.rev_option")) { |v| rev = v }
            o.on("-o", "--output DIR", t(:"export.output_option")) { |v| output = v }
          end
          return 0 unless args
          raise Error, t(:"export.at_and_rev") if at && rev

          git = @context.git
          tracking = HostTracking.new(git)
          raise Error, t(:"export.no_branch", branch: HostTracking::BRANCH) unless tracking.tip

          commit = if at
                     commit_at(git, at)
                   elsif rev
                     commit_of_rev(git, rev)
                   else
                     tracking.tip
                   end
          tree = git.ls_tree(commit)
          paths = args.empty? ? tree.keys.sort : args.map { |arg| resolve_path(tree, arg) }.uniq

          dir = File.expand_path(output || default_dir(git, commit), @context.cwd)
          raise Error, t(:"export.exists", dir: dir) if File.exist?(dir) || File.symlink?(dir)

          write(git, tree, paths, dir)
          print_result(git, commit, paths, dir)
          0
        end

        private

        def commit_at(git, at)
          time = begin
            Time.parse(at)
          rescue ArgumentError
            raise Error, t(:"export.invalid_time", at: at)
          end
          commit = git.run("rev-list", "-1", "--before=#{time.iso8601}", HostTracking::REF).strip
          raise Error, t(:"export.none_before", time: time.strftime("%Y-%m-%d %H:%M:%S")) if commit.empty?

          commit
        end

        # host-trackingは一直線の履歴なので、指定したコミットとの共通の祖先が、
        # そのコミットの時点で取り込んでいた最新の取得の時点になる
        def commit_of_rev(git, rev)
          commit = git.rev_parse(rev)
          raise Error, t(:"export.no_commit", rev: rev) unless commit

          base = git.merge_base(commit, HostTracking::REF)
          raise Error, t(:"export.not_merged", rev: rev, branch: HostTracking::BRANCH) unless base

          base
        end

        # Root configからのパスと、リポジトリ上のパスのどちらでも指定できる
        def resolve_path(tree, arg)
          validate_path!(arg)
          [HostTracking.repo_path(arg), arg].find { |path| tree.key?(path) } or
            raise Error, t(:"export.not_in_snapshot", path: arg)
        end

        def default_dir(git, commit)
          date = git.run("log", "-1", "--format=%cd", "--date=format-local:%Y%m%d-%H%M%S", commit).strip
          "export-#{date}-#{commit[0, 7]}"
        end

        def write(git, tree, paths, dir)
          FileUtils.mkdir_p(dir)
          paths.each do |path|
            dest = File.join(dir, path)
            FileUtils.mkdir_p(File.dirname(dest))
            File.open(dest, File::WRONLY | File::CREAT | File::EXCL | File::BINARY) do |f|
              f.write(git.cat_blob(tree.fetch(path)))
            end
          end
        end

        def print_result(git, commit, paths, dir)
          info = git.run("log", "-1", "--format=%cd%x00%s", "--date=format-local:%Y-%m-%d %H:%M:%S", commit).strip
          date, subject = info.split("\0", 2)
          out.puts "#{HostTracking::BRANCH}: #{commit[0, 7]} (#{date}) #{subject}"
          out.puts t(:"export.written", dir: dir)
          paths.each { |path| out.puts "  #{path}" }
        end
      end
    end
  end
end
