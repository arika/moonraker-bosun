# moonraker-bosun

## 概要

Klipperのホストにある設定ファイルとMoonraker DBの内容を、Moonraker APIを通して取得し、gitで管理するツール(gem)です。
gem名は`moonraker-bosun`、コマンド名は`bosun`です。

実装済みの機能や使い方については @README.ja.md を参照してください。
英語版の @README.md は要約で、原本は README.ja.md です。

トラッキングの設計(gitの運用方法)については @docs/design.md を参照してください。

## 方針

機能を追加・変更するときも守り続ける方針です。

### 対象とする環境

* Moonraker APIだけを使い、Web UI(Mainsail、Fluiddなど)や環境(MainsailOSなど)には依存しない
  * 特定のWeb UIに関わる機能(バックアップするnamespaceなど)は、複数のWeb UIを同じように扱う

### ホストへの書き込み

* Moonrakerが`rw`と報告しないファイルには書き込まない(更新・追加・削除のいずれも)
  * 必要なときは`bosun`を使わず、Web UIやSSHで行う
* 削除は明示的な操作(`bosun rm`)をしない限り行わない
* 設定を有効にするための再起動(RESTARTなど)は行わない

### プリンタの制御

行わない。

### ディレクトリ構成(データ)

`bosun`を実行するgitリポジトリ(データのリポジトリ)では、次のディレクトリを使う。

| ディレクトリ | ホスト側のディレクトリ | 説明 |
| --- | --- | --- |
| config | ~/printer_data/config(Moonrakerのroot `config`) | |
| backup/moonraker-db | - | Moonraker DBのnamespaceごとのバックアップ(`<namespace>.json`)を置く |

## 実装したい機能(構想)

このセクションには、必要な機能や実装したい機能を列挙します。
実際に実装するかどうかは、運用しながら検討します。

実装した内容は @README.ja.md の「機能」セクションに記載して、このセクションからは削除する方針です。
つまり、このセクションは構想やTODOのような位置付けであり、 @README.ja.md の「機能」セクションは使い方であるとともに確定した仕様書のような位置付けです。

現在、構想として残っているものはありません。
設計上の未決事項は @docs/design.md の「未決事項」を参照してください。

## 実装方法

* Rubyで実装する
  * 実行時の依存はdefault gem(とgemになっていない標準ライブラリ)に限り、gemspecに実行時の依存を加えない
    * bundled gem(minitest、rakeなど、Rubyと一緒にインストールされるが、Bundlerの下ではgemspecに書かないとrequireできないもの)は使わない
    * default gemはRubyのバージョンが上がるとbundled gemに移ることがあるので、`dependencies_test.rb`で確かめている(`Gem::BUNDLED_GEMS::SINCE`に入っているものも使わない)
    * default gemをgemspecに書くと、インストールのときに新しい版を入れようとすることがある(opensslのようなネイティブ拡張はビルドが必要になる)ので、新しい版の機能が必要な場合を除いて書かない
  * 開発時の依存(テスト、Lintなど)は、有力なgemがあれば使ってよい。`Gemfile`で管理する
* ホストとのやり取りはMoonraker APIを使用する
  * Moonraker APIには認証を設定しないことを前提とする(ローカルネットワークやVPNの中で使う)
  * Moonraker APIでは実現できない場合にはSSHでの接続を使用する
  * Moonraker APIの動作は @docs/moonraker-api.md を参照
* gem名は`moonraker-bosun`、コマンド名は`bosun`(甲板長。MainsailやMoonrakerと同じ帆船の用語)
  * モジュールは`Moonraker::Bosun`、requireは`moonraker/bosun`
* Ruby 3.4以降に対応する(3.4と4.0でテストする)
  * 3.4で使えない機能は使わない。RuboCopの`TargetRubyVersion`も3.4にしている
  * 開発環境はRuby 3.4.11とする(`.ruby-version`)
  * Bundlerは、Ruby 3.4.11に同梱のもの(2.6.9)を使い、更新しない
    * `Gemfile.lock`の`BUNDLED WITH`も2.6.9にしておく。新しいBundlerで`Gemfile.lock`を作り直すと、3.4.11で実行したときにそのBundlerがインストールされてしまうため
* gitの操作は外部ライブラリを使わず、`Open3`でgitコマンドを実行する
* ライセンスはMIT

### メッセージ

* 表示するメッセージは日本語と英語を用意する(`lib/moonraker/bosun/messages/catalog.rb`)
  * jaが原本。メッセージを追加・変更するときは、両方の言語を同時に書く
  * 文字列を直接書かず、`t(:"<キー>", 名前: 値)`で参照する。値は`%{名前}`に埋め込まれる
  * 英語は、エラー(`bosun: `に続けて表示するもの)は小文字で始め、それ以外は大文字で始める
* 言語は`LC_ALL`、`LC_MESSAGES`、`LANG`の順に見て、`ja`で始まれば日本語、それ以外は英語にする
  * 言語は`CLI#run`の実行中だけスレッドごとに設定する(テストを並列に実行するため)
* gitに記録するメッセージ(マージコミットなど)は、言語によらず英語にする
  * `host-tracking`のコミットメッセージは、機械で読み取る固定の形式(docs/design.mdを参照)
* テストは、既存のものは日本語(`LANG=ja_JP.UTF-8`)で確かめ、英語は代表的なものだけを確かめる
  * カタログの両方の言語がそろっていること、使っているキーがあることは`messages_test.rb`で確かめる

### ドキュメント

* README.ja.mdが原本で、README.md(英語)はその要約
  * 仕様を変えたらREADME.ja.mdを直し、要約に関わる変更(コマンドの追加など)ならREADME.mdにも反映する
* AGENTS.mdとdocs/は日本語だけとする

### CIとリリース

* GitHub(https://github.com/arika/moonraker-bosun)のActionsを使う
  * `.github/workflows/main.yml`: `main`へのpushとpull requestで、Ruby 3.4と4.0の`bundle exec rake`(テストとRuboCop)を実行する
  * `.github/workflows/push_gem.yml`: `v*`のタグのpushで、Trusted Publishingでrubygems.orgに公開する(Environmentは`release`)
* 利用者に伝えるべき変更(機能の追加、挙動の変更、不具合の修正など)は、CHANGELOG.mdの`## [Unreleased]`に日本語で書く
* リリースの手順
  1. `lib/moonraker/bosun/version.rb`の版を上げ、CHANGELOG.mdの`## [Unreleased]`を`## [<版>] - <日付>`にして、新しい`## [Unreleased]`を加えてコミットする
  2. `v<版>`のタグを打ち、GitHubにpushする
* `Gemfile.lock`には、CIのために`x86_64-linux`のプラットフォームも入れている

### Lint

* RuboCopを使用する(`.rubocop.yml`)
* 設定した閾値を超えているMetricsは`.rubocop_todo.yml`に記録している。分割などで解消したら、そこから削除する

### ディレクトリ構成(コード)

| ディレクトリ | 内容 |
| --- | --- |
| exe | 実行ファイル(`exe/bosun`) |
| lib | ライブラリ(`lib/moonraker/bosun.rb`、`lib/moonraker/bosun/`) |
| test | テスト(`test/moonraker/bosun/**/*_test.rb`)と、テスト用の偽物など(`test/support/`) |
| docs | 設計や調査結果のドキュメント |

### テスト

* minitestを使用する
  * gitコマンドの実行に時間がかかるので、テストは並列に実行する(`parallelize_me!`)
  * そのため、テストの中でカレントディレクトリや環境変数を変更しない
* `bundle exec rake`で、テストとRuboCopを実行する(`rake test`、`rake rubocop`で個別に実行できる)
* gitの操作は、一時ディレクトリに作成した実際のリポジトリでテストする
* Moonrakerとの通信は、クライアントを差し替えられるようにして、テストではメモリ上の偽物を使う
* `Client`自体のテストは、テストごとに起動するWEBrickのサーバー(`test/support/http_stub.rb`)を相手にする
  * WebMockは使わない。スタブの登録がプロセス全体で共有されるため、並列実行と相性が悪い
* 実機でホストへの書き込みを試すときは、どこからもincludeされていないダミーのファイルを使う

## その他

* ユーザとのやり取りは日本語で行うこと
* 不明な点があれば、ユーザに質問して確認すること
* 用語: 「追跡」は使わず「トラッキング」とする。gitのuntracked filesは「git管理外のファイル」と書き分ける
