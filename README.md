# dataset-overturemaps

[Overture Maps Foundation](https://overturemaps.org/) が公開するオープンな地図データのうち、
places テーマの日本の POI を Queria のカタログ（[data.queria.io](https://data.queria.io/)）へ
取り込むデータセットです。

## データ出典

Overture は月1回ほどリリースを出し、古いリリースは数か月で配布元から消えます。版を固定せず、
ビルドのたびに配布元のバケット（`s3://overturemaps-us-west-2/release/`）を一覧して最新のリリースを
取ります。取り込んだリリース名は `release` 列に入ります。

places テーマのうち、住所の国コードが JP のレコードだけを取り出します。外接矩形だけで絞ると
韓国・ロシア極東・中国の一部が混ざるためです。

提供元ごとにライセンスが違い、各レコードの `source_licenses` 列がそのレコードのライセンスを示します。

| 提供元 | ライセンス | 件数 |
| --- | --- | ---: |
| Meta・Microsoft・PinMeTo・DAC など | CDLA-Permissive-2.0 | 全件（Overture 自身の分を含む） |
| AllThePlaces | CC0-1.0 | 約 37 万 |
| Foursquare | Apache-2.0 | 約 33 万 |

Foursquare 由来のデータには [NOTICE](https://opensource.foursquare.com/places-notice-txt/) が
適用されます。全文と Queria による変更の通知は `dataset.yml` の説明に載せてあり、カタログの
データセットページに表示されます。

## 収録テーブル

| テーブル | 内容 | 行数 |
| --- | --- | ---: |
| `places.place` | 日本の POI。1行が1施設。主な列を平坦化してある | 2,914,402 |
| `places.raw_place` | 同じ行を Overture のスキーマのまま全列で持つ | 2,914,402 |

`place` に無い情報（名前の言語別・別名、副カテゴリ、SNS・メールアドレス、2件目以降の住所、
提供元ごとの元レコード ID と更新時刻など）は `raw_place` にあります。列の意味は
[Overture のスキーマ](https://docs.overturemaps.org/schema/reference/places/place/)を見てください。

行数はリリース 2026-09-23.1 の実測です。

カテゴリは Overture 独自の英語の分類で、`basic_category`（262種）、`taxonomy_primary`（1,415種）、
`taxonomy_hierarchy`（最大6段）の3つの粒度があります。同じ業態でも施設によって付いている粒度が
違うので、細かいカテゴリで数えると取りこぼします。

`operating_status`（営業状態）はほとんどのレコードで空です。閉店した施設を除く用途には使えません。
