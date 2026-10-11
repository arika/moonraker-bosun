# frozen_string_literal: true

module Moonraker
  module Bosun
    module Messages
      # jaが原本。enはその翻訳
      #
      # 英語は、エラー(bosun: に続けて表示するもの)は小文字で始め、それ以外は大文字で始める。
      CATALOG = {
        # 共通
        "common.help_option": {
          ja: "この説明を表示する",
          en: "Show this help"
        },
        "common.root_option": {
          ja: "Rootディレクトリ(省略時はconfig)",
          en: "Root directory (default: config)"
        },
        "common.invalid_option": {
          ja: "オプションが不正です: %{message}",
          en: "invalid option: %{message}"
        },
        "common.invalid_path": {
          ja: "ファイルの指定が不正です: %{path}",
          en: "invalid file path: %{path}"
        },
        "common.no_arguments": {
          ja: "%{command}には引数を指定できません: %{args}",
          en: "%{command} takes no arguments: %{args}"
        },
        "common.no_tracked_files": {
          ja: "トラッキング中のファイルがありません。bosun add でトラッキングを始めてください",
          en: "no files are tracked; start tracking with bosun add"
        },
        "common.file_not_on_host": {
          ja: "ホストにファイルがありません: %{path}",
          en: "file not found on the host: %{path}"
        },
        "common.fetched": {
          ja: "取得しました: %{path}",
          en: "Fetched: %{path}"
        },
        "common.printing": {
          ja: "印刷中のため中止しました(print_stats.state: %{state})",
          en: "aborted because the printer is printing (print_stats.state: %{state})"
        },
        "common.not_fetched": {
          ja: "%{label}(取得していません):",
          en: "%{label} (not fetched):"
        },

        # CLI
        "cli.usage": {
          ja: <<~TEXT,
            使い方: bosun <コマンド> [引数...]

            コマンド:
            %{commands}

            各コマンドの説明は bosun <コマンド> --help で表示します。
          TEXT
          en: <<~TEXT
            Usage: bosun <command> [args...]

            Commands:
            %{commands}

            Run bosun <command> --help for details of each command.
          TEXT
        },
        "cli.interrupted": {
          ja: "中断しました",
          en: "interrupted"
        },
        "cli.unknown_command": {
          ja: "不明なコマンドです: %{name}",
          en: "unknown command: %{name}"
        },

        # 設定、Moonraker、git
        "config.not_set": {
          ja: "環境変数%{name}が設定されていません",
          en: "environment variable %{name} is not set"
        },
        "config.not_http": {
          ja: "%{name}はhttp://またはhttps://で始まるURLを指定してください: %{url}",
          en: "%{name} must be a URL starting with http:// or https://: %{url}"
        },
        "config.invalid_url": {
          ja: "%{name}のURLが不正です: %{url}",
          en: "invalid URL in %{name}: %{url}"
        },
        "client.api_error": {
          ja: "Moonrakerがエラーを返しました(%{code}): %{message}",
          en: "Moonraker returned an error (%{code}): %{message}"
        },
        "client.invalid_response": {
          ja: "Moonrakerの応答を解釈できません(%{context}): %{message}",
          en: "cannot parse the response from Moonraker (%{context}): %{message}"
        },
        "client.connection_failed": {
          ja: "Moonrakerに接続できません(%{url}): %{message}",
          en: "cannot connect to Moonraker (%{url}): %{message}"
        },
        "git.not_repository": {
          ja: "gitリポジトリの中で実行してください: %{dir}",
          en: "run inside a git repository: %{dir}"
        },
        "git.failed": {
          ja: "gitコマンドが失敗しました(git %{command}): %{message}",
          en: "git command failed (git %{command}): %{message}"
        },

        # 除外する理由
        "exclusion.read_only": {
          ja: "rwでない",
          en: "not rw"
        },
        "exclusion.backup": {
          ja: "バックアップファイル",
          en: "backup file"
        },

        # 状態(SyncStatus)
        "state.host_modified.label": {
          ja: "ホストで変更",
          en: "Modified on the host"
        },
        "state.host_modified.guide": {
          ja: "bosun pull で取り込む",
          en: "Fetch with bosun pull"
        },
        "state.local_modified.label": {
          ja: "ローカルで変更",
          en: "Modified locally"
        },
        "state.local_modified.guide": {
          ja: "bosun push でホストに反映する",
          en: "Apply to the host with bosun push"
        },
        "state.both_modified.label": {
          ja: "ホストとローカルの両方で変更",
          en: "Modified both on the host and locally"
        },
        "state.both_modified.guide": {
          ja: "bosun pull でマージしてから、bosun push でホストに反映する",
          en: "Merge with bosun pull, then apply to the host with bosun push"
        },
        "state.host_deleted.label": {
          ja: "ホストで削除",
          en: "Deleted on the host"
        },
        "state.host_deleted.guide": {
          ja: "トラッキングをやめるなら bosun forget <ファイル>",
          en: "To stop tracking, run bosun forget <file>"
        },
        "state.both_deleted.label": {
          ja: "ホストとローカルの両方で削除",
          en: "Deleted both on the host and locally"
        },
        "state.both_deleted.guide": {
          ja: "トラッキングをやめるなら bosun forget <ファイル>",
          en: "To stop tracking, run bosun forget <file>"
        },
        "state.host_read_only.label": {
          ja: "ホストで書き込めなくなった",
          en: "No longer writable on the host"
        },
        "state.host_read_only.guide": {
          ja: "Web UIやSSHで確認する。トラッキングをやめるなら bosun forget <ファイル>",
          en: "Check it with the web UI or SSH. To stop tracking, run bosun forget <file>"
        },
        "state.local_deleted.label": {
          ja: "ローカルで削除",
          en: "Deleted locally"
        },
        "state.local_deleted.guide": {
          ja: "ホストからも削除するなら bosun rm <ファイル>\n" \
              "ローカルに戻すなら git restore --source=%{branch} --staged --worktree -- %{dir}/<ファイル> " \
              "を実行してコミットする",
          en: "To delete it on the host as well, run bosun rm <file>\n" \
              "To restore it locally, run git restore --source=%{branch} --staged --worktree -- %{dir}/<file> " \
              "and commit"
        },
        "state.host_modified_local_deleted.label": {
          ja: "ホストで変更、ローカルで削除",
          en: "Modified on the host, deleted locally"
        },
        "state.host_modified_local_deleted.guide": {
          ja: "bosun pull で取り込んでから判断する",
          en: "Fetch with bosun pull, then decide"
        },
        "state.local_added.label": {
          ja: "ローカルで追加",
          en: "Added locally"
        },
        "state.local_added.guide": {
          ja: "bosun push でホストに作成する",
          en: "Create it on the host with bosun push"
        },
        "state.added_on_both.label": {
          ja: "ホストとローカルの両方にある(トラッキングしていない)",
          en: "Exists both on the host and locally (not tracked)"
        },
        "state.added_on_both.guide": {
          ja: "bosun add <ファイル> で取り込んでマージする",
          en: "Fetch and merge it with bosun add <file>"
        },
        "state.untracked.label": {
          ja: "トラッキングしていない",
          en: "Not tracked"
        },
        "state.untracked.guide": {
          ja: "トラッキングするなら bosun add <ファイル>",
          en: "To track it, run bosun add <file>"
        },
        "state.synced.label": {
          ja: "同期済み",
          en: "In sync"
        },

        # host-tracking
        "tracking.detached_head": {
          ja: "ブランチをチェックアウトした状態で実行してください(detached HEADです)",
          en: "check out a branch first (HEAD is detached)"
        },
        "tracking.on_tracking_branch": {
          ja: "%{branch}ブランチでは実行できません。mainなどの作業用のブランチで実行してください",
          en: "cannot run on the %{branch} branch; run on a working branch such as main"
        },
        "tracking.no_head": {
          ja: "HEADにコミットがありません",
          en: "HEAD has no commits"
        },
        "tracking.merge_in_progress": {
          ja: "マージの途中です。マージを完了するか中止してから実行してください",
          en: "a merge is in progress; complete or abort it first"
        },
        "tracking.staged_changes": {
          ja: "ステージ済みの変更があります。コミットするか、git stashで退避してから実行してください",
          en: "there are staged changes; commit them or stash them with git stash first"
        },
        "tracking.dirty": {
          ja: "次のファイルに未コミットの変更があります。コミットするか、git stashで退避してから実行してください:\n%{paths}",
          en: "the following files have uncommitted changes; commit them or stash them with git stash first:\n%{paths}"
        },
        "tracking.merge_conflict": {
          ja: "%{branch}のマージで衝突しました。%{branch}へのコミットは完了しています。\n" \
              "衝突を解決してgit commitするか、git merge --abortで中止してください。\n%{output}",
          en: "merging %{branch} resulted in conflicts. The commit to %{branch} has been completed.\n" \
              "Resolve the conflicts and run git commit, or abort with git merge --abort.\n%{output}"
        },
        "tracking.merge_failed": {
          ja: "%{branch}をマージできませんでした。%{branch}へのコミットは完了しています。\n" \
              "原因を取り除いてから、git merge --no-ff %{branch}を実行してください。\n%{output}",
          en: "could not merge %{branch}. The commit to %{branch} has been completed.\n" \
              "Remove the cause, then run git merge --no-ff %{branch}.\n%{output}"
        },
        "tracking.committed": {
          ja: "%{branch}にコミットしました: %{commit}",
          en: "Committed to %{branch}: %{commit}"
        },
        "tracking.changed": {
          ja: "  変更: %{path}",
          en: "  changed: %{path}"
        },
        "tracking.removed": {
          ja: "  削除: %{path}",
          en: "  removed: %{path}"
        },
        "tracking.no_change": {
          ja: "%{branch}の内容に変更はありません",
          en: "No changes in %{branch}"
        },
        "tracking.merged": {
          ja: "%{branch}にマージしました",
          en: "Merged into %{branch}"
        },
        "tracking.merge_incomplete": {
          ja: "マージが完了していません",
          en: "the merge is not complete"
        },

        # 不変条件
        "invariant.merge_commit": {
          ja: "%{commit}: マージコミットです(親が%{count}個あります)",
          en: "%{commit}: merge commit (%{count} parents)"
        },
        "invariant.no_op": {
          ja: "%{commit}: Host-Opがありません(bosunが作成したコミットではありません)",
          en: "%{commit}: no Host-Op (not created by bosun)"
        },
        "invariant.unknown_op": {
          ja: "%{commit}: 不明なHost-Opです: %{op}",
          en: "%{commit}: unknown Host-Op: %{op}"
        },
        "invariant.outside": {
          ja: "%{commit}: %{dirs}以外のファイルがあります: %{paths}",
          en: "%{commit}: files outside %{dirs}: %{paths}"
        },
        "invariant.dir_separator": {
          ja: "と",
          en: " and "
        },
        "invariant.more": {
          ja: " ほか%{count}件",
          en: " and %{count} more"
        },
        "invariant.db_missing": {
          ja: "%{commit}: Host-DBに記録したファイルがツリーにありません: %{path}",
          en: "%{commit}: file recorded in Host-DB is not in the tree: %{path}"
        },
        "invariant.deleted_present": {
          ja: "%{commit}: Host-Fileに削除と記録したファイルがツリーにあります: %{path}",
          en: "%{commit}: file recorded as deleted in Host-File is in the tree: %{path}"
        },
        "invariant.file_missing": {
          ja: "%{commit}: Host-Fileに記録したファイルがツリーにありません: %{path}",
          en: "%{commit}: file recorded in Host-File is not in the tree: %{path}"
        },
        "invariant.size_mismatch": {
          ja: "%{commit}: Host-Fileに記録したサイズ(%{recorded})がblobのサイズ(%{actual})と違います: %{path}",
          en: "%{commit}: size recorded in Host-File (%{recorded}) differs from the blob size (%{actual}): %{path}"
        },

        # roots
        "roots.summary": {
          ja: "ホストのRootディレクトリの一覧を表示する",
          en: "List root directories on the host"
        },
        "roots.usage": {
          ja: "使い方: bosun roots [オプション]",
          en: "Usage: bosun roots [options]"
        },
        "roots.long_option": {
          ja: "権限とホスト側のパスも表示する",
          en: "Also show permissions and paths on the host"
        },

        # ls
        "ls.summary": {
          ja: "ホストのファイル一覧を表示する",
          en: "List files on the host"
        },
        "ls.usage": {
          ja: "使い方: bosun ls [オプション]",
          en: "Usage: bosun ls [options]"
        },
        "ls.all_option": {
          ja: "除外しているファイルも表示する",
          en: "Also show excluded files"
        },
        "ls.long_option": {
          ja: "権限、サイズ、更新日時も表示する",
          en: "Also show permissions, sizes and modification times"
        },
        "ls.excluded": {
          ja: "(除外: %{reason})",
          en: "(excluded: %{reason})"
        },

        # get
        "get.summary": {
          ja: "ホストのファイルをカレントディレクトリに取得する",
          en: "Download files from the host into the current directory"
        },
        "get.usage": {
          ja: "使い方: bosun get [オプション] ファイル...",
          en: "Usage: bosun get [options] FILE..."
        },
        "get.no_files": {
          ja: "取得するファイルを指定してください",
          en: "specify files to download"
        },
        "get.duplicated": {
          ja: "保存するファイル名が重複しています: %{names}",
          en: "duplicate file names to save: %{names}"
        },
        "get.exists": {
          ja: "カレントディレクトリに同名のファイルがあるため、取得を中止しました: %{names}",
          en: "aborted because files with the same names exist in the current directory: %{names}"
        },

        # add
        "add.summary": {
          ja: "ホストのファイルを取得してトラッキングを始める",
          en: "Fetch files from the host and start tracking them"
        },
        "add.usage": {
          ja: "使い方: bosun add ファイル...",
          en: "Usage: bosun add FILE..."
        },
        "add.no_files": {
          ja: "トラッキングするファイルを指定してください",
          en: "specify files to track"
        },
        "add.excluded": {
          ja: "トラッキングの対象にできないファイルです(%{reason}): %{path}",
          en: "cannot track this file (%{reason}): %{path}"
        },

        # pull
        "pull.summary": {
          ja: "トラッキング中のファイルをホストから一括で取得する",
          en: "Fetch all tracked files from the host"
        },
        "pull.usage": {
          ja: "使い方: bosun pull",
          en: "Usage: bosun pull"
        },

        # status、audit
        "status.summary": {
          ja: "ホストとローカルの設定ファイルの状態を表示する",
          en: "Show the state of configuration files on the host and locally"
        },
        "status.usage": {
          ja: "使い方: bosun status",
          en: "Usage: bosun status"
        },
        "status.no_tip": {
          ja: "%{branch}: まだありません。bosun add でトラッキングを始めてください",
          en: "%{branch}: does not exist yet. Start tracking with bosun add"
        },
        "status.unmerged": {
          ja: "注意: %{branch}に、まだ現在のブランチに取り込んでいないコミットがあります",
          en: "Warning: %{branch} has commits not yet merged into the current branch"
        },
        "status.unmerged_guide": {
          ja: "git merge --no-ff %{branch} で取り込んでください(取り込むまで、以下の判定は正しくありません)",
          en: "Merge them with git merge --no-ff %{branch} (the states below are not accurate until then)"
        },
        "status.all_synced": {
          ja: "すべて同期済みです(%{count}件)",
          en: "All files are in sync (%{count})"
        },
        "status.synced_count": {
          ja: "同期済み: %{count}件",
          en: "In sync: %{count}"
        },
        "status.renames": {
          ja: "ホストで名前を変更した可能性があります:",
          en: "Possibly renamed on the host:"
        },
        "status.rename_guide": {
          ja: "bosun add %{to} と bosun forget %{from} で、新しい名前のトラッキングに切り替える",
          en: "Switch tracking to the new name with bosun add %{to} and bosun forget %{from}"
        },
        "status.dirty": {
          ja: "未コミットの変更(判定はHEADの内容で行っています):",
          en: "Uncommitted changes (states are determined from HEAD):"
        },
        "audit.summary": {
          ja: "内容まで比べて同期の状態を検査し、不変条件も検査する",
          en: "Check sync states by comparing contents, and check invariants"
        },
        "audit.usage": {
          ja: "使い方: bosun audit",
          en: "Usage: bosun audit"
        },
        "audit.invariants_ok": {
          ja: "%{branch}の不変条件: 問題なし",
          en: "Invariants of %{branch}: OK"
        },
        "audit.invariants_violated": {
          ja: "%{branch}の不変条件の違反:",
          en: "Invariant violations in %{branch}:"
        },
        "audit.repair_guide": {
          ja: "%{branch}を修復する必要があります。git log %{branch} で経緯を確認してください",
          en: "%{branch} needs to be repaired. Check its history with git log %{branch}"
        },
        "audit.design_guide": {
          ja: "不変条件は docs/design.md の「不変条件」を参照してください",
          en: "See the invariants (不変条件) section in docs/design.md"
        },
        "audit.ok": {
          ja: "問題はありません",
          en: "No problems found"
        },
        "audit.ng": {
          ja: "問題があります",
          en: "Problems found"
        },

        # diff
        "diff.summary": {
          ja: "最後に取得した内容と、ローカル(HEAD)の内容の差分を表示する",
          en: "Show differences between the last fetched contents and local (HEAD)"
        },
        "diff.usage": {
          ja: "使い方: bosun diff [オプション] [ファイル...]",
          en: "Usage: bosun diff [options] [FILE...]"
        },
        "diff.stat_option": {
          ja: "変更の概要だけを表示する",
          en: "Show only a summary of changes"
        },

        # push
        "push.summary": {
          ja: "ローカルでの変更をホストに反映する",
          en: "Apply local changes to the host"
        },
        "push.usage": {
          ja: "使い方: bosun push [オプション]",
          en: "Usage: bosun push [options]"
        },
        "push.dry_run_option": {
          ja: "反映する内容を表示するだけで、ホストには書き込まない",
          en: "Only show what would be applied, without writing to the host"
        },
        "push.create": {
          ja: "作成: %{path}",
          en: "Create: %{path}"
        },
        "push.update": {
          ja: "更新: %{path}",
          en: "Update: %{path}"
        },
        "push.nothing": {
          ja: "反映する変更はありません",
          en: "No changes to apply"
        },
        "push.problems": {
          ja: "反映できないファイル:",
          en: "Files that cannot be applied:"
        },
        "push.skipped": {
          ja: "%{label}(反映しません):",
          en: "%{label} (not applied):"
        },
        "push.aborted": {
          ja: "反映できないファイルがあるため、中止しました(ホストには何も書き込んでいません)",
          en: "Aborted because some files cannot be applied (nothing was written to the host)"
        },
        "push.dry_run": {
          ja: "--dry-run のため、ホストには書き込んでいません",
          en: "Nothing was written to the host (--dry-run)"
        },
        "push.uploaded": {
          ja: "アップロードしました: %{path}",
          en: "Uploaded: %{path}"
        },
        "push.upload_failed": {
          ja: "アップロードの途中で失敗しました。反映していないファイル: %{paths}",
          en: "upload failed partway. Files not applied: %{paths}"
        },
        "push.record_failed": {
          ja: "反映したファイルの記録にも失敗しました。bosun pull で取り込んでください: %{message}",
          en: "also failed to record the applied files. Fetch them with bosun pull: %{message}"
        },
        "push.changed_since_plan": {
          ja: "確認の後にホストでファイルが変わったため、中止しました(ホストには何も書き込んでいません): %{paths}",
          en: "aborted because files changed on the host after the check (nothing was written to the host): %{paths}"
        },
        "push.uploaded_missing": {
          ja: "アップロードしたファイルがホストにありません: %{paths}",
          en: "uploaded files are not on the host: %{paths}"
        },
        "push.content_mismatch": {
          ja: "警告: ホストの内容が反映した内容と違います(ホストの内容を記録します): %{path}",
          en: "warning: the contents on the host differ from the applied contents " \
              "(recording the host contents): %{path}"
        },
        "push.restart": {
          ja: "反映した設定を有効にするには、Web UIなどから再起動(KlipperならRESTART)を行ってください(bosunでは行いません)",
          en: "To activate the applied configuration, restart from the web UI or elsewhere " \
              "(RESTART for Klipper). bosun does not restart"
        },
        "plan.host_deleted": {
          ja: "ホストで削除されています",
          en: "deleted on the host"
        },
        "plan.host_deleted_guide": {
          ja: "ローカルの内容でホストに作り直す操作はまだありません。トラッキングをやめるなら bosun forget <ファイル>",
          en: "there is no operation yet to recreate it on the host from the local contents. " \
              "To stop tracking, run bosun forget <file>"
        },
        "plan.not_writable": {
          ja: "ホストで書き込めません(rwでない)",
          en: "not writable on the host (not rw)"
        },
        "plan.not_writable_guide": {
          ja: "Web UIやSSHで確認する",
          en: "check it with the web UI or SSH"
        },
        "plan.host_modified": {
          ja: "ホストで変更されています(最後に取得した内容と一致しません)",
          en: "modified on the host (does not match the last fetched contents)"
        },
        "plan.pull_guide": {
          ja: "bosun pull で取り込んでから、もう一度 bosun push を実行する",
          en: "fetch with bosun pull, then run bosun push again"
        },
        "plan.exists": {
          ja: "ホストに同名のファイルがあります",
          en: "a file with the same name exists on the host"
        },
        "plan.exists_guide": {
          ja: "bosun add <ファイル> で取り込んでマージしてから、もう一度 bosun push を実行する",
          en: "fetch and merge it with bosun add <file>, then run bosun push again"
        },
        "plan.backup_name": {
          ja: "ホスト側のバックアップファイルと同じ形式の名前です",
          en: "the name has the same form as backup files created on the host"
        },
        "plan.backup_name_guide": {
          ja: "ファイル名を変える",
          en: "rename the file"
        },
        "plan.not_regular_file": {
          ja: "通常のファイルではありません(gitのモード: %{mode})",
          en: "not a regular file (git mode: %{mode})"
        },
        "plan.not_regular_file_guide": {
          ja: "シンボリックリンクや実行可能ファイルは反映できない。通常のファイル(モード100644)としてコミットし直す",
          en: "symbolic links and executable files cannot be applied. Commit it as a regular file (mode 100644)"
        },
        "plan.unmerged": {
          ja: "%{branch}に、まだ現在のブランチに取り込んでいないコミットがあります。" \
              "git merge --no-ff %{branch} で取り込んでから実行してください",
          en: "%{branch} has commits not yet merged into the current branch; " \
              "merge them with git merge --no-ff %{branch} first"
        },

        # forget、rm
        "remove.not_tracked": {
          ja: "トラッキングしていないファイルです: %{paths}",
          en: "not tracked: %{paths}"
        },
        "remove.locally_modified": {
          ja: "ローカル(HEAD)で変更されているファイルは対象にできません: %{paths}\n" \
              "→ 変更を戻すなら git restore --source=%{branch} --staged --worktree -- %{dir}/<ファイル> " \
              "を実行してコミットする",
          en: "files modified locally (HEAD) cannot be specified: %{paths}\n" \
              "→ To discard the changes, run git restore --source=%{branch} --staged --worktree -- %{dir}/<file> " \
              "and commit"
        },
        "forget.summary": {
          ja: "ホストのファイルを残したまま、トラッキングをやめる",
          en: "Stop tracking files, keeping them on the host"
        },
        "forget.usage": {
          ja: "使い方: bosun forget ファイル...",
          en: "Usage: bosun forget FILE..."
        },
        "forget.no_files": {
          ja: "トラッキングをやめるファイルを指定してください",
          en: "specify files to stop tracking"
        },
        "forget.kept": {
          ja: "ホストのファイルは削除していません",
          en: "The files on the host were not deleted"
        },
        "rm.summary": {
          ja: "ホストのファイルを削除し、トラッキングをやめる",
          en: "Delete files on the host and stop tracking them"
        },
        "rm.usage": {
          ja: "使い方: bosun rm [オプション] ファイル...",
          en: "Usage: bosun rm [options] FILE..."
        },
        "rm.dry_run_option": {
          ja: "削除するファイルを表示するだけで、ホストのファイルは削除しない",
          en: "Only show the files to delete, without deleting them on the host"
        },
        "rm.no_files": {
          ja: "削除するファイルを指定してください",
          en: "specify files to delete"
        },
        "rm.plan": {
          ja: "削除: %{path}",
          en: "Delete: %{path}"
        },
        "rm.dry_run": {
          ja: "--dry-run のため、ホストのファイルは削除していません",
          en: "No files on the host were deleted (--dry-run)"
        },
        "rm.host_deleted": {
          ja: "%{path}: ホストで削除されています → トラッキングをやめるなら bosun forget %{path}",
          en: "%{path}: deleted on the host → To stop tracking, run bosun forget %{path}"
        },
        "rm.not_writable": {
          ja: "%{path}: ホストで書き込めません(rwでない) → Web UIやSSHで確認する",
          en: "%{path}: not writable on the host (not rw) → Check it with the web UI or SSH"
        },
        "rm.host_modified": {
          ja: "%{path}: ホストで変更されています(最後に取得した内容と一致しません) → bosun pull で取り込んでから判断する",
          en: "%{path}: modified on the host (does not match the last fetched contents) → " \
              "Fetch with bosun pull, then decide"
        },
        "rm.aborted": {
          ja: "削除できないファイルがあるため、中止しました(ホストのファイルは削除していません):\n%{details}",
          en: "aborted because some files cannot be deleted (no files on the host were deleted):\n%{details}"
        },
        "rm.deleted": {
          ja: "削除しました: %{path}",
          en: "Deleted: %{path}"
        },
        "rm.delete_failed": {
          ja: "削除の途中で失敗しました。削除していないファイル: %{paths}",
          en: "deletion failed partway. Files not deleted: %{paths}"
        },
        "rm.record_failed": {
          ja: "削除したファイルの記録にも失敗しました: %{message}",
          en: "also failed to record the deleted files: %{message}"
        },
        "rm.changed_since_check": {
          ja: "確認の後にホストでファイルが変わったため、中止しました(ホストのファイルは削除していません): %{paths}",
          en: "aborted because files changed on the host after the check (no files on the host were deleted): %{paths}"
        },

        # backup
        "backup.summary": {
          ja: "Moonraker DBの内容をbackup/moonraker-db/に取得する",
          en: "Back up Moonraker DB contents into backup/moonraker-db/"
        },
        "backup.usage": {
          ja: "使い方: bosun backup [オプション] [namespace...]",
          en: "Usage: bosun backup [options] [namespace...]"
        },
        "backup.status_option": {
          ja: "namespaceごとに、バックアップしているかなどの状態を表示する",
          en: "Show whether each namespace is backed up"
        },
        "backup.invalid_namespace": {
          ja: "namespaceの指定が不正です: %{namespace}",
          en: "invalid namespace: %{namespace}"
        },
        "backup.missing_requested": {
          ja: "ホストにnamespaceがありません: %{namespaces}",
          en: "namespaces not found on the host: %{namespaces}"
        },
        "backup.first": {
          ja: "まだ何もバックアップしていないので、次のnamespaceのうちホストにあるものをバックアップします: %{namespaces}",
          en: "Nothing is backed up yet. Backing up those of the following namespaces that exist on the host: " \
              "%{namespaces}"
        },
        "backup.no_targets": {
          ja: "バックアップするnamespaceがありません",
          en: "no namespaces to back up"
        },
        "backup.missing": {
          ja: "ホストにないnamespace(取得していません):",
          en: "Namespaces not on the host (not fetched):"
        },
        "backup.missing_guide": {
          ja: "バックアップをやめる操作はまだありません",
          en: "There is no operation yet to stop backing up"
        },
        "backup.recommended": {
          ja: "バックアップしていないnamespace(推奨):",
          en: "Recommended namespaces not backed up:"
        },
        "backup.recommended_guide": {
          ja: "バックアップするなら bosun backup <namespace>",
          en: "To back up, run bosun backup <namespace>"
        },
        "backup.note.tracked": {
          ja: "バックアップ中",
          en: "backed up"
        },
        "backup.note.not_on_host": {
          ja: "ホストにない",
          en: "not on the host"
        },
        "backup.note.recommended": {
          ja: "推奨",
          en: "recommended"
        },
        "backup.note_separator": {
          ja: "、",
          en: ", "
        },

        # export
        "export.summary": {
          ja: "ある時点で取得していたファイルを、ディレクトリに書き出す",
          en: "Write the files fetched as of a point in time to a directory"
        },
        "export.usage": {
          ja: "使い方: bosun export [オプション] [ファイル...]",
          en: "Usage: bosun export [options] [FILE...]"
        },
        "export.at_option": {
          ja: "その日時より前で、最も新しい取得の時点(例: \"2026-10-11 15:00\")",
          en: "The latest fetch before this date and time (e.g. \"2026-10-11 15:00\")"
        },
        "export.rev_option": {
          ja: "そのコミット(mainのコミットも可)の時点で取り込んでいた取得の時点",
          en: "The latest fetch merged as of this commit (a commit on main is also accepted)"
        },
        "export.output_option": {
          ja: "書き出すディレクトリ(省略時は ./export-<日時>-<コミット>)",
          en: "Output directory (default: ./export-<datetime>-<commit>)"
        },
        "export.at_and_rev": {
          ja: "--atと--revは同時に指定できません",
          en: "--at and --rev cannot be used together"
        },
        "export.no_branch": {
          ja: "%{branch}がありません。bosun add でトラッキングを始めてください",
          en: "%{branch} does not exist; start tracking with bosun add"
        },
        "export.exists": {
          ja: "書き出すディレクトリがすでにあります: %{dir}",
          en: "output directory already exists: %{dir}"
        },
        "export.invalid_time": {
          ja: "日時を解釈できません: %{at}",
          en: "cannot parse the date and time: %{at}"
        },
        "export.none_before": {
          ja: "%{time}より前に取得したものがありません",
          en: "nothing was fetched before %{time}"
        },
        "export.no_commit": {
          ja: "コミットが見つかりません: %{rev}",
          en: "commit not found: %{rev}"
        },
        "export.not_merged": {
          ja: "%{rev}の時点では、まだ%{branch}を取り込んでいません",
          en: "%{branch} had not been merged yet as of %{rev}"
        },
        "export.not_in_snapshot": {
          ja: "その時点のファイルにありません: %{path}",
          en: "not in the files as of that point: %{path}"
        },
        "export.written": {
          ja: "書き出しました: %{dir}",
          en: "Wrote: %{dir}"
        }
      }.freeze
    end
  end
end
