# moonraker-bosun

[English](README.md)

Klipperのホストにある設定ファイルとMoonraker DBの内容を、Moonraker APIを通して取得し、gitで管理するためのツールです。
コマンド名は`bosun`です。

* ホストから取得した内容を、専用のブランチ`host-tracking`に記録します
* ローカルで編集した設定を、ホストで変更されていないことを確かめてから反映します
* 印刷中はホストに書き込みません。Klipperの再起動(RESTARTなど)も行いません
* Mainsail、FluiddなどのWeb UIや、MainsailOSなどの環境には依存しません(Moonraker APIだけを使います)

gitの運用方法(トラッキングの設計)は[docs/design.md](docs/design.md)を参照してください。

## 必要なもの

* Ruby 3.4以降
* git
* Moonraker API(認証なしで接続できること)
  * Moonrakerの認証(APIキーなど)にはまだ対応していません。ローカルネットワークやVPN(Tailscaleなど)の中で使うことを想定しています

## インストール

```bash
gem install moonraker-bosun
```

ソースからインストールする場合:

```bash
git clone <このリポジトリ>
cd moonraker-bosun
bundle install
bundle exec rake install
```

## 使い方

設定を管理するためのgitリポジトリを用意し、その中で実行します。
`bosun`は、カレントディレクトリを含むgitリポジトリの`config/`と`backup/`を使います。

```bash
mkdir my-printer && cd my-printer
git init
git commit --allow-empty -m "初期化"    # bosunはHEADにコミットがあることを前提にします

export MOONRAKER_BASE_URL=http://<ホスト名>:7125
bosun ls                                 # ホストの設定ファイルの一覧
bosun add printer.cfg moonraker.conf     # トラッキングを始める
bosun backup                             # Moonraker DB(Web UIの設定など)のバックアップ
```

その後は、次のように使います。

```bash
bosun status         # ホストとローカルの状態を確認する
bosun pull           # ホストでの変更(SAVE_CONFIGなど)を取り込む
vi config/printer.cfg && git commit -am "設定を変更"
bosun push -n        # ホストに反映する内容を確認する
bosun push           # ホストに反映する
```

### 接続先の指定

Moonraker APIの接続先のベースURLを、環境変数`MOONRAKER_BASE_URL`で指定します。

```bash
export MOONRAKER_BASE_URL=http://mainsailos.local:7125
```

### メッセージの言語

メッセージは日本語と英語で表示できます。
環境変数`LC_ALL`、`LC_MESSAGES`、`LANG`の順に見て、最初に設定されている値が`ja`で始まれば日本語、それ以外は英語で表示します。
このREADMEの出力例は日本語の場合のものです。

```bash
export LANG=ja_JP.UTF-8
```

gitに記録するメッセージ(マージコミットなど)は、表示の言語によらず英語です。

## 機能

### 共通

* `-r ROOT`、`--root ROOT`で対象のRootディレクトリ(`config`、`logs`、`config_examples`など)を指定する
  * 省略時は`config`
* `bosun <コマンド> --help`で、コマンドごとの説明を表示する

### 対象から除外するファイル

Root `config`の次のファイルは、`ls`で表示しない。
他のRootでは除外しない。

* Moonrakerが`permissions`を`rw`と報告しないファイル(シンボリックリンクなど)
* ホスト側で作られるバックアップファイル
  * Klipperの`SAVE_CONFIG`によるもの: `<名前>-YYYYMMDD_HHMMSS.cfg`
  * Moonrakerによるもの: `.<名前>.bkp`

### `bosun roots`

ホストのRootディレクトリの一覧を表示する。

```bash
bosun roots [-l]
```

* Moonrakerが返す順(`config`が先頭)に、1行に1つ表示する
* `-l`、`--long`: 権限とホスト側のパスも表示する

```
$ bosun roots -l
rw  config           /home/a/printer_data/config
r   logs             /home/a/printer_data/logs
rw  gcodes           /home/a/printer_data/gcodes
r   config_examples  /home/a/klipper/config
r   docs             /home/a/klipper/docs
```

### `bosun ls`

ホストのファイル一覧を表示する。

```bash
bosun ls [-r ROOT] [-a] [-l]
```

* パスの順に並べて、1行に1ファイルを表示する
* `-a`、`--all`: 除外しているファイルも表示する
* `-l`、`--long`: 権限、サイズ、更新日時も表示する
  * `-a`と組み合わせると、除外しているファイルに理由を付けて表示する

```
$ bosun ls -la
rw   1307  2026-09-30 15:45:55  .moonraker.conf.bkp  (除外: バックアップファイル)
rw   2507  2026-05-07 04:58:34  crowsnest.conf
r   16493  2026-05-07 04:58:26  mainsail.cfg  (除外: rwでない)
rw   2767  2026-10-11 14:11:06  printer.cfg
```

### `bosun get`

ホストのファイルを、git管理下に置かずにカレントディレクトリに取得する。

```bash
bosun get [-r ROOT] ファイル...
```

* 除外しているファイルも取得できる
  * シンボリックリンクは、リンク先の内容を取得する
* サブディレクトリのファイルは、ファイル名だけで保存する(`macros/a.cfg`は`a.cfg`になる)
* 次の場合は、何も保存せずに中止する
  * カレントディレクトリに同名のファイルがある
  * 保存するファイル名が重複している
  * 指定したファイルのいずれかがホストにない

### `bosun add`

Root `config`のファイルを取得して、トラッキングを始める。

```bash
bosun add ファイル...
```

* ホストから取得した内容を`host-tracking`ブランチにコミットし、現在のブランチにマージする
  * リポジトリ上のパスは`config/<ファイル>`になる
  * gitの運用方法は[docs/design.md](docs/design.md)を参照
* トラッキング中のファイルを指定した場合は、取得し直す
  * 内容が変わっていなければ、コミットしない
* 除外しているファイル(`bosun ls`で表示しないファイル)は指定できない
* 次の場合は、ホストから取得する前に中止する
  * detached HEADの場合、`host-tracking`ブランチの場合、マージの途中の場合
  * ステージ済みの変更がある場合
  * 指定したファイルなどに、未コミットの変更やgit管理外のファイルがある場合
* マージで衝突した場合は、衝突を解決して`git commit`するか、`git merge --abort`で中止する
  * `host-tracking`へのコミットは完了しているので、取得し直す必要はない

```
$ bosun add printer.cfg moonraker.conf
取得しました: config/printer.cfg
取得しました: config/moonraker.conf
host-trackingにコミットしました: 374ed20
  変更: config/moonraker.conf
  変更: config/printer.cfg
mainにマージしました
```

### `bosun pull`

トラッキング中のファイルを、ホストから一括で取得する。

```bash
bosun pull
```

* `add`と同様に、`host-tracking`ブランチにコミットし、現在のブランチにマージする
  * 内容が変わったファイルがなければ、コミットしない
  * `host-tracking`に未マージのコミットがあれば、変更がなくてもマージする
* 次のファイルは取得せず、警告して手順を案内する
  * ホストで削除されたファイル(トラッキングは続ける。やめる場合は`bosun forget`)
  * ホストで`rw`でなくなったファイル
  * トラッキングしていないファイル
* 中止する条件やマージで衝突した場合の扱いは、`add`と同じ
  * 未コミットの変更などを確認する対象は、トラッキング中のすべてのファイル

```
$ bosun pull
取得しました: config/crowsnest.conf
取得しました: config/moonraker.conf
取得しました: config/printer.cfg
取得しました: config/sonar.conf
host-trackingにコミットしました: 6edaa72
  変更: config/printer.cfg
mainにマージしました
```

### `bosun status`

ホスト、`host-tracking`(最後に取得した内容)、`HEAD`の3つを比べて、Root `config`のファイルの状態を表示する。

```bash
bosun status
```

* 同期済みでないファイルを状態ごとにまとめ、解消するための手順を案内する
  * 状態の一覧は[docs/design.md](docs/design.md)の「状態の判定」を参照
* ホストで削除されたファイルと同じ内容のトラッキングしていないファイルがあれば、名前の変更の可能性として表示する
* `HEAD`の内容で判定する。`config/`の未コミットの変更は、別に表示する
* `host-tracking`に、まだ現在のブランチに取り込んでいないコミットがあれば警告する
* ホストの内容は、ファイル一覧の更新日時とサイズで判定する
  * 更新日時だけが変わったファイルは、取得して内容を比べる
  * 更新日時とサイズが同じまま内容が変わった場合は検知できない(`bosun audit`で検知する)

```
$ bosun status
host-tracking: 388820b (2026-10-11 14:46:50)

ローカルで変更:
  moonraker.conf
  → bosun push でホストに反映する

ホストで削除:
  bosun-probe.cfg
  → トラッキングをやめるなら bosun forget <ファイル>

同期済み: 3件
```

### `bosun audit`

`status`と同じ内容を、トラッキング中のすべてのファイルを取得して厳密に判定する。
あわせて、`host-tracking`ブランチの不変条件を検査する。

```bash
bosun audit
```

* 不変条件は、`host-tracking`のすべてのコミットについて次のことを検査する
  * マージコミットでないこと
  * `Host-Op`があり、既知の操作であること(`bosun`以外で作られたコミットがないこと)
  * `config/`と`backup/`以外のファイルがないこと
  * `Host-File`に記録したファイルがツリーにあり、サイズが一致すること
  * `Host-File`に削除と記録したファイルが、ツリーにないこと
  * `Host-DB`に記録したファイルがツリーにあること
* 問題があれば終了コードを1にする
  * 不変条件の違反、同期済みでないファイル、名前の変更の可能性、`host-tracking`の未マージのコミット
  * トラッキングしていないファイルは表示するが、問題としない(あえてトラッキングしないこともあるため)
  * 未コミットの変更は表示するが、問題としない

```
$ bosun audit
host-tracking: 3d7e0ff (2026-10-11 14:42:16)

すべて同期済みです(4件)

host-trackingの不変条件: 問題なし

問題はありません
```

### `bosun diff`

最後に取得した内容(`host-tracking`)と、ローカル(`HEAD`)の内容の差分を表示する。
`bosun push`で反映される内容の確認に使う。

```bash
bosun diff [--stat] [ファイル...]
```

* `git diff host-tracking HEAD -- config/`と同じ
  * ホストの現在の内容との差分ではない(ホストでの変更は`bosun status`で確認する)
  * 未コミットの変更は含めない
* ファイルを指定すると、そのファイルに限る
* `--stat`: 変更の概要だけを表示する

### `bosun push`

ローカル(`HEAD`)での変更を、ホストに反映する。

```bash
bosun push [-n]
```

* `HEAD`にあり、最後に取得した内容と異なるファイルを反映の対象にする
  * 最後に取得した内容にあれば更新、なければ作成
  * 反映する内容は`bosun diff`で確認できる
* `-n`、`--dry-run`: 反映する内容を表示するだけで、ホストには書き込まない
* 次の場合は、何も反映せずに中止する(終了コードは1)
  * 印刷中(`print_stats.state`が`printing`または`paused`)
  * `config/`に未コミットの変更やgit管理外のファイルがある、ステージ済みの変更がある、`host-tracking`に未マージのコミットがある
  * 反映できないファイルが1件でもある
    * 共通: 通常のファイル(gitのモードが`100644`)でない(シンボリックリンク、実行可能ファイルなど)
    * 更新: ホストで変更されている(内容を取得して確認する)、ホストで削除されている、`rw`でない
    * 作成: ホストに同名のファイルがある、ホスト側のバックアップファイルと同じ形式の名前
  * 確認の後、書き込む直前までにホストでファイルが変わった
* ローカルで削除したファイルや、ホストだけで変更されたファイルは反映せず、状態と手順を案内する
* 反映した後、ホストから取得し直して`host-tracking`にコミットし、現在のブランチにマージする
  * アップロードの途中で失敗した場合や、Ctrl-Cで中断した場合も、反映できたファイルは記録する
* 設定を有効にするための再起動(KlipperのRESTARTなど)は行わない

```
$ bosun push
作成: macros.cfg
更新: printer.cfg

アップロードしました: macros.cfg
アップロードしました: printer.cfg
取得しました: config/macros.cfg
取得しました: config/printer.cfg
host-trackingにコミットしました: b98b680
  変更: config/macros.cfg
  変更: config/printer.cfg
mainにマージしました

反映した設定を有効にするには、Web UIなどから再起動(KlipperならRESTART)を行ってください(bosunでは行いません)
```

### `bosun forget`

ホストのファイルを残したまま、トラッキングをやめる。

```bash
bosun forget ファイル...
```

* `host-tracking`からファイルを除いてコミットし、現在のブランチにマージする(ローカルからも削除される)
* ホストには接続しない(ホストがオフラインでも実行できる)
* 次の場合は中止する
  * トラッキングしていないファイルを指定した
  * 未コミットの変更などがある(`add`と同じ)
  * ローカル(`HEAD`)で変更されている
    * 変更を戻すか、ローカルで削除してから実行する

```
$ bosun forget crowsnest.conf
host-trackingにコミットしました: 0531f23
  削除: config/crowsnest.conf
mainにマージしました

ホストのファイルは削除していません
```

### `bosun rm`

ホストのファイルを削除し、トラッキングをやめる。

```bash
bosun rm [-n] ファイル...
```

* `forget`と同じ確認に加えて、次の場合は何も削除せずに中止する
  * 印刷中
  * ホストで変更されている(内容を取得して確認する)、ホストで削除されている、`rw`でない
  * 確認の後、削除する直前までにホストでファイルが変わった
* ホストのファイルを削除した後、`host-tracking`から除いてコミットし、現在のブランチにマージする
* `-n`、`--dry-run`: 削除するファイルを表示するだけで、ホストのファイルは削除しない

```
$ bosun rm old-macros.cfg
削除: old-macros.cfg

削除しました: old-macros.cfg
host-trackingにコミットしました: 47a9d3f
  削除: config/old-macros.cfg
mainにマージしました
```

### `bosun backup`

Moonraker DBの内容(Mainsailの設定など)を、`backup/moonraker-db/<namespace>.json`に取得する。

```bash
bosun backup [namespace...]
bosun backup --status
```

* `add`や`pull`と同じく、`host-tracking`ブランチにコミットし、現在のブランチにマージする
  * キーを辞書順に並べた、整形したJSONで保存する
  * 内容が変わらなければコミットしない
* `bosun backup <namespace>...`: 指定したnamespaceを取得し、バックアップを始める
* `bosun backup`: バックアップしているnamespaceをすべて取得し直す
  * まだ何もバックアップしていない場合は、`mainsail`、`fluidd`、`mobileraker`、`maintenance`、`webcams`、`timelapse`のうち、ホストにあるものを取得する
  * これらのうち、まだバックアップしていないものがホストにあれば案内する
* `-s`、`--status`: namespaceごとに、バックアップしているか(バックアップ中、推奨、ホストにない)を表示する
* ホストへの書き戻し(復元)は行わない
* `status`と`audit`の同期の状態の判定には含めない

```
$ bosun backup
まだ何もバックアップしていないので、次のnamespaceのうちホストにあるものをバックアップします: mainsail, fluidd, mobileraker, maintenance, webcams, timelapse
取得しました: backup/moonraker-db/mainsail.json
取得しました: backup/moonraker-db/maintenance.json
host-trackingにコミットしました: a1c9d88
  変更: backup/moonraker-db/mainsail.json
  変更: backup/moonraker-db/maintenance.json
mainにマージしました
```

### `bosun export`

ある時点で取得していたファイル(スナップショット)を、ディレクトリに書き出す。
ホストにも作業ツリーにも書き込まない。

```bash
bosun export [--at 日時 | --rev コミット] [-o ディレクトリ] [ファイル...]
```

* 時点の指定(省略時は最後に取得した時点)
  * `--at 日時`: その日時より前で、最も新しい取得の時点(例: `--at "2026-10-11 15:00"`)
  * `--rev コミット`: そのコミットの時点で取り込んでいた、最新の取得の時点
    * `main`のコミットも、`host-tracking`のコミットも指定できる
* `-o`、`--output`: 書き出すディレクトリ
  * 省略時は、カレントディレクトリの`export-<日時>-<コミット>/`
  * すでにある場合は中止する
* ファイルを指定すると、そのファイルだけを書き出す(`printer.cfg`のようなRoot `config`からのパスか、`backup/moonraker-db/mainsail.json`のようなリポジトリ上のパス)
* 書き出すのは「その時点までに最後に取得した内容の集まり」であり、「その時点でホストにあったすべてのファイル」ではない
  * `bosun add`は指定したファイルだけを取得するため
  * ローカルでの変更は含まれない

```
$ bosun export --rev b16ee8d -o /tmp/snapshot
host-tracking: 3d7e0ff (2026-10-11 14:42:16) add: 4 files
書き出しました: /tmp/snapshot
  config/crowsnest.conf
  config/moonraker.conf
  config/printer.cfg
  config/sonar.conf
```

## 開発

Ruby 3.4以降に対応しています。実行時には標準ライブラリだけを使い、開発時に使うgem(minitest、RuboCop、WEBrickなど)は`Gemfile`で管理しています。
開発環境はRuby 3.4.11(`.ruby-version`)で、Bundlerは3.4.11に同梱のもの(2.6.9)を使います。

```bash
bundle install
bundle exec rake               # テストとRuboCop
bundle exec rake test          # テスト
bundle exec rake rubocop       # RuboCop
bundle exec rake build         # pkg/にgemを作る
bundle exec rake install       # gemを作ってインストールする
```

## ライセンス

[MIT License](LICENSE)
