"""Overture Maps の places テーマから日本の POI を取り出す。

Overture は月1回ほどリリースを出し、古いリリースは数か月で配布元から消える。
版を固定すると取れなくなるので、毎回バケットを一覧して最新のリリースを使う。

配布元は匿名で読める S3（us-west-2）の GeoParquet。bbox の列で絞ると
DuckDB が行グループの統計で読み飛ばすので、全世界のファイルを落とさずに済む。
bbox には韓国・ロシア極東・中国の一部が入るので、住所の国コードで日本に絞る。

出力: data/places/place.parquet（1行 = 1 POI）

データソース: Overture Maps Foundation
https://docs.overturemaps.org/guides/places/
"""

import logging
import re
from pathlib import Path
from urllib.request import Request, urlopen
from xml.etree import ElementTree

import duckdb

logger = logging.getLogger("pipelines")

USER_AGENT = "dataset-overturemaps (+https://github.com/queria-io/dataset-overturemaps)"

BUCKET = "overturemaps-us-west-2"
REGION = "us-west-2"
LIST_URL = f"https://{BUCKET}.s3.{REGION}.amazonaws.com/?list-type=2&prefix=release/&delimiter=/"

# リリース名は YYYY-MM-DD.N。.N は同じ日の再リリース
RELEASE_PATTERN = re.compile(r"^release/(\d{4}-\d{2}-\d{2}\.\d+)/$")

# 日本の外接矩形。端は沖ノ鳥島 北緯 20.42 / 択捉島 北緯 45.55 /
# 与那国島 東経 122.93 / 南鳥島 東経 153.98
JAPAN_BBOX = {"xmin": 122.0, "xmax": 154.5, "ymin": 20.0, "ymax": 46.0}

OUTPUT_DIR = Path("data/places")


def latest_release() -> str:
    request = Request(LIST_URL, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=60) as response:
        root = ElementTree.fromstring(response.read())
    namespace = {"s3": root.tag.split("}")[0].strip("{")}
    releases = [
        match.group(1)
        for prefix in root.iterfind("s3:CommonPrefixes/s3:Prefix", namespace)
        if (match := RELEASE_PATTERN.match(prefix.text or ""))
    ]
    if not releases:
        raise RuntimeError(f"no release found in {LIST_URL}")
    # .N は文字列で比べると .10 が .9 より前に来るので、数として比べる
    return max(releases, key=lambda name: (name.split(".")[0], int(name.split(".")[1])))


def extract_places(release: str, output: Path) -> int:
    source = f"s3://{BUCKET}/release/{release}/theme=places/type=place/*.parquet"
    con = duckdb.connect()
    for extension in ("httpfs", "spatial"):
        con.install_extension(extension)
        con.load_extension(extension)
    con.execute(f"SET s3_region = '{REGION}'")
    # 匿名で読む。認証情報を探しに行かせない
    con.execute(f"CREATE SECRET overture (TYPE s3, PROVIDER config, REGION '{REGION}')")

    con.execute(
        f"""
        COPY (
            SELECT
                id,
                names.primary AS name,
                names.common['ja'] AS name_ja,
                names.common['en'] AS name_en,
                basic_category,
                taxonomy.primary AS taxonomy_primary,
                array_to_string(taxonomy.hierarchy, ' > ') AS taxonomy_hierarchy,
                confidence,
                operating_status,
                brand.names.primary AS brand_name,
                brand.wikidata AS brand_wikidata,
                addresses[1].freeform AS address,
                addresses[1].locality AS locality,
                addresses[1].region AS region,
                addresses[1].postcode AS postcode,
                array_to_string(phones, ' ') AS phones,
                array_to_string(websites, ' ') AS websites,
                array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.dataset))), ', ')
                    AS source_datasets,
                array_to_string(list_sort(list_distinct(list_transform(sources, s -> s.license))), ', ')
                    AS source_licenses,
                ST_Y(geometry) AS lat,
                ST_X(geometry) AS lon,
                version,
                '{release}' AS release
            FROM read_parquet('{source}', hive_partitioning = false)
            WHERE bbox.xmin BETWEEN {JAPAN_BBOX['xmin']} AND {JAPAN_BBOX['xmax']}
              AND bbox.ymin BETWEEN {JAPAN_BBOX['ymin']} AND {JAPAN_BBOX['ymax']}
              AND addresses[1].country = 'JP'
        ) TO '{output}' (FORMAT parquet, COMPRESSION zstd)
        """
    )
    return con.execute(f"SELECT count(*) FROM '{output}'").fetchone()[0]


def download_places() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    release = latest_release()
    logger.info("Overture release %s", release)

    rows = extract_places(release, OUTPUT_DIR / "place.parquet")
    logger.info("places: %d rows", rows)
    if rows == 0:
        raise RuntimeError(f"release {release} has no place in Japan")

