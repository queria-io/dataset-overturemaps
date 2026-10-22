"""Overture Maps の buildings テーマから日本の建物を取り出す。

building（建物の外形）と building_part（高層部など建物の部分）の 2 つを取る。
どちらも国コードを持たないので、transportation と同じく日本の国の範囲を少し膨らませた
ポリゴンで、外接矩形の中心が入るものに絞る。国の範囲は、先に pipelines/divisions.py が
取り出した日本の division_area から作る（全世界の division_area を読み直さない）。

日本の建物は OpenStreetMap・Microsoft ML Buildings・Shi らの推定（Zenodo）が提供元で、
2026-10-21.0 で約 5,400 万棟ある。高さや階数を持つのは OSM 由来の一部だけ。

出力:
- data/buildings/building.parquet（1行 = 1棟）
- data/buildings/building_part.parquet（1行 = 建物の 1 部分。building_id で building を指す）

データソース: Overture Maps Foundation
https://docs.overturemaps.org/guides/buildings/
"""

import logging
from pathlib import Path

from pipelines.divisions import OUTPUT_DIR as DIVISIONS_DIR
from pipelines.places import BUCKET, connect_overture
from pipelines.transportation import bbox_filter, create_japan

logger = logging.getLogger("pipelines")

OUTPUT_DIR = Path("data/buildings")


def extract_buildings(release: str, output_dir: Path) -> tuple[int, int]:
    base = f"s3://{BUCKET}/release/{release}"
    con = connect_overture()
    division_area = DIVISIONS_DIR / "division_area.parquet"
    if not division_area.exists():
        raise RuntimeError(f"{division_area} is missing; run download_divisions first")
    create_japan(con, str(division_area))

    counts = []
    for kind in ("building", "building_part"):
        output = output_dir / f"{kind}.parquet"
        con.execute(
            f"""
            COPY (
                SELECT b.*, '{release}' AS release
                FROM read_parquet('{base}/theme=buildings/type={kind}/*.parquet', hive_partitioning = false) AS b,
                    japan
                WHERE {bbox_filter('b.bbox')}
                  AND st_intersects(japan.geometry, st_point((b.bbox.xmin + b.bbox.xmax) / 2, (b.bbox.ymin + b.bbox.ymax) / 2))
            ) TO '{output}' (FORMAT parquet, COMPRESSION zstd)
            """
        )
        counts.append(con.execute(f"SELECT count(*) FROM '{output}'").fetchone()[0])
    return counts[0], counts[1]


def download_buildings(release: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    buildings, parts = extract_buildings(release, OUTPUT_DIR)
    logger.info("buildings: %d buildings, %d parts", buildings, parts)
    if buildings == 0:
        raise RuntimeError(f"release {release} has no building in Japan")
