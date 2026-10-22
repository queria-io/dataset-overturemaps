"""Overture Maps の transportation テーマから日本の道路網を取り出す。

segment（道路の区間）と connector（区間どうしをつなぐ点）の 2 つを取る。
segment は交差点をまたいで長く続き、途中のどこで他の道とつながるかを
connectors 列（connector の ID と区間上の位置 at）で持つ。交差点で区切る
のは dbt のマートで行う。

segment は国コードを持たないので、Overture の divisions テーマにある日本の
国の範囲で絞る。そのままの境界だと海沿いや島の道が外れるので 0.05 度
（約 5km）膨らませる。いちばん近い隣国（対馬と釜山、宗谷と樺太）でも
40km 以上離れているので、隣国の道は入らない。

places と同じく、毎回バケットを一覧して最新のリリースを使う。

出力:
- data/transportation/segment.parquet（1行 = 1区間、道路だけ）
- data/transportation/connector.parquet（日本の外接矩形の connector 全部。
  使うものだけを dbt で segment と突き合わせて残す）

データソース: Overture Maps Foundation
https://docs.overturemaps.org/guides/transportation/
"""

import logging
from pathlib import Path

from pipelines.places import BUCKET, JAPAN_BBOX, connect_overture

logger = logging.getLogger("pipelines")

OUTPUT_DIR = Path("data/transportation")

# 日本の範囲をどれだけ膨らませるか（度）。上の説明のとおり、隣国との距離より十分小さい
JAPAN_MARGIN_DEG = 0.05


def bbox_filter(column: str = "bbox") -> str:
    return f"""
        {column}.xmin BETWEEN {JAPAN_BBOX['xmin']} AND {JAPAN_BBOX['xmax']}
        AND {column}.ymin BETWEEN {JAPAN_BBOX['ymin']} AND {JAPAN_BBOX['ymax']}
    """


def extract_transportation(release: str, output_dir: Path) -> tuple[int, int]:
    base = f"s3://{BUCKET}/release/{release}"
    con = connect_overture()

    con.execute(
        f"""
        CREATE TABLE japan AS
        SELECT st_buffer(st_union_agg(geometry), {JAPAN_MARGIN_DEG}) AS geometry
        FROM read_parquet('{base}/theme=divisions/type=division_area/*.parquet', hive_partitioning = false)
        WHERE country = 'JP' AND subtype = 'country'
        """
    )

    segment = output_dir / "segment.parquet"
    con.execute(
        f"""
        COPY (
            SELECT s.*, '{release}' AS release
            FROM read_parquet('{base}/theme=transportation/type=segment/*.parquet', hive_partitioning = false) AS s,
                japan
            WHERE {bbox_filter('s.bbox')}
              AND s.subtype = 'road'
              AND st_intersects(japan.geometry, st_point((s.bbox.xmin + s.bbox.xmax) / 2, (s.bbox.ymin + s.bbox.ymax) / 2))
        ) TO '{segment}' (FORMAT parquet, COMPRESSION zstd)
        """
    )

    connector = output_dir / "connector.parquet"
    con.execute(
        f"""
        COPY (
            SELECT *
            FROM read_parquet('{base}/theme=transportation/type=connector/*.parquet', hive_partitioning = false)
            WHERE {bbox_filter()}
        ) TO '{connector}' (FORMAT parquet, COMPRESSION zstd)
        """
    )

    segments, connectors = (con.execute(f"SELECT count(*) FROM '{path}'").fetchone()[0] for path in (segment, connector))
    return segments, connectors


def download_transportation(release: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    segments, connectors = extract_transportation(release, OUTPUT_DIR)
    logger.info("transportation: %d segments, %d connectors", segments, connectors)
    if segments == 0:
        raise RuntimeError(f"release {release} has no road segment in Japan")
