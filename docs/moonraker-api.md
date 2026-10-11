# Moonraker APIの調査結果

`bosun`の実装に必要なMoonraker APIの動作を、実機で確認した結果をまとめる。

* 確認日: 2026-10-11
* 確認した環境: Moonraker v0.11.0-3-g9e676eb(API 1.5.0)、Klipper v0.13.0-787-ge2b99a915
* プリンタの電源は入っていない状態(Klipperは`error`状態)で確認した

## Root

`GET /server/files/roots`

| Root | ホスト側のディレクトリ | 権限 |
| --- | --- | --- |
| config | ~/printer_data/config | rw |
| logs | ~/printer_data/logs | r |
| gcodes | ~/printer_data/gcodes | rw |
| config_examples | ~/klipper/config | r |
| docs | ~/klipper/docs | r |

## ファイルの一覧

`GET /server/files/list?root=config`

```json
{"result": [
  {"path": "printer.cfg", "modified": 1791695466.5512717, "size": 2767, "permissions": "rw"},
  {"path": "mainsail.cfg", "modified": 1778097506.7109838, "size": 16493, "permissions": "r"}
]}
```

* `path`はRootからの相対パス。サブディレクトリ内のファイルも含めて再帰的に返る
* `modified`は秒単位の浮動小数点数で、マイクロ秒程度の精度がある(ホスト側の`st_mtime`)
* `GET /server/files/directory?path=config&extended=true`でも同じ情報が得られる(`filename`、ディレクトリ単位)

### permissions

Moonrakerの`file_manager.py`(`get_path_info`)の実装と実機の結果から、次のように決まる。

* `rw`: 通常のファイル
* `r`: 次のいずれか
  * 書き込みできないRoot(`logs`、`config_examples`など)のファイル
  * **シンボリックリンク**(`mainsail.cfg`、`timelapse.cfg`)
  * Moonrakerの予約パス(読み取り可)の下にあるファイル
* `""`: `.git`の下にあるファイル、または読み取りも禁止された予約パスの下にあるファイル

シンボリックリンクかどうかを直接示す項目はない。`bosun`では種類を判別せず、`permissions`が`rw`かどうかだけで判断する(design.mdの「対象のファイル」を参照)。
`modified`と`size`はリンク先のファイルの値になる。

## ファイルのダウンロード

`GET /server/files/{root}/{path}`

* 本文がファイルの内容。`Last-Modified`ヘッダが付く
* シンボリックリンクは、リンク先の内容が返る
* 存在しない場合は`404`

## ファイルのアップロード

`POST /server/files/upload`(multipart/form-data)

* フィールド: `root`(省略時は`gcodes`)、`file`、`path`(任意、サブディレクトリ)、`checksum`(任意、SHA-256の16進文字列)
* 同名のファイルがあれば**確認なしに上書きする**
  * 新規作成と上書きのどちらでも`"action": "create_file"`が返る
  * そのため、新しいファイルを作るときに同名のファイルがないことは、`bosun`の側で確認する必要がある
* `checksum`が一致しない場合は`422`
* 応答の`item`に、アップロード後の`modified`、`size`、`permissions`が含まれる
* **シンボリックリンクと同名のファイルをアップロードすると、リンク先のファイルを書き換える**(実装で確認、実機では未実施)
  * `bosun`は`rw`でないファイルに書き込まないので、`mainsail.cfg`などへのアップロードは起きない

## ファイルの削除

`DELETE /server/files/{root}/{path}`

* 成功すると`"action": "delete_file"`が返る
* 存在しない場合は`400`(`404`ではない)

## ホスト側で作られるバックアップファイル

| 作成元 | 名前 | 例 |
| --- | --- | --- |
| Klipperの`SAVE_CONFIG` | `<名前>-YYYYMMDD_HHMMSS.cfg` | `printer-20261011_141106.cfg` |
| Moonrakerの設定の書き換え | `.<名前>.bkp` | `.moonraker.conf.bkp` |

* Klipper: `klippy/configfile.py`の`time.strftime("-%Y%m%d_%H%M%S")`
* Moonraker: `confighelper.py`の`f".{cfg.name}.bkp"`

## 印刷状態

`GET /printer/objects/query?print_stats`

* 通常は`result.status.print_stats.state`が`standby`、`printing`、`paused`、`complete`、`cancelled`、`error`のいずれか
* Klipperが`ready`でない場合(プリンタの電源が入っていないなど)は、`print_stats`が空のオブジェクトになる
  * この場合、印刷は行われていない
* Klipperの状態は`GET /printer/info`の`result.state`(`ready`、`error`、`shutdown`、`startup`)で得られる

## データベース

`GET /server/database/list`、`GET /server/database/item?namespace=<名前>`

* namespace: `maintenance`、`moonraker`、`mainsail`、`update_manager`、`gcode_metadata`、`announcements`
* Mainsailの設定は`mainsail`にある(`dashboard`、`general`、`gcodeViewer`、`view`など)
* `moonraker`、`update_manager`、`gcode_metadata`、`announcements`は、Moonrakerが内部で管理する情報が中心

## エラー

* エラーの場合は`{"error": {"code": ..., "message": ..., "traceback": ...}}`が返る
* `traceback`はMoonraker内部のPythonのトレースバックなので、ユーザには`code`と`message`だけを示す
