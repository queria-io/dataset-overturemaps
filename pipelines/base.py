"""Overture Maps の base テーマから日本の範囲の地物を取り出す。

base は OpenStreetMap 由来の地物を種類（type）ごとに分けたテーマで、ここでは infrastructure
（バス停・信号・電柱・橋・トイレなどの設備）を取る。国コードを持たないので、buildings と
同じく日本の国の範囲を少し膨らませたポリゴンに、外接矩形の中心が入るものに絞る。

base の GERS ID は 2026-09 のリリースで全件振り直されたので、ほかのテーマほどリリースを
またいで安定していない。

出力: data/base/<type>.parquet（1行 = 1 地物）

データソース: Overture Maps Foundation
https://docs.overturemaps.org/guides/base/
"""

import logging
from pathlib import Path

from pipelines.divisions import OUTPUT_DIR as DIVISIONS_DIR
from pipelines.places import BUCKET, connect_overture
from pipelines.transportation import bbox_filter, create_japan

logger = logging.getLogger("pipelines")

OUTPUT_DIR = Path("data/base")

TYPES = ("infrastructure",)


def extract_base(release: str, output_dir: Path) -> dict[str, int]:
    base = f"s3://{BUCKET}/release/{release}"
    con = connect_overture()
    division_area = DIVISIONS_DIR / "division_area.parquet"
    if not division_area.exists():
        raise RuntimeError(f"{division_area} is missing; run download_divisions first")
    create_japan(con, str(division_area))

    def extract(kind: str) -> int:
        output = output_dir / f"{kind}.parquet"
        con.execute(
            f"""
            COPY (
                SELECT b.*, '{release}' AS release
                FROM read_parquet('{base}/theme=base/type={kind}/*.parquet', hive_partitioning = false) AS b,
                    japan
                WHERE {bbox_filter('b.bbox')}
                  AND st_intersects(japan.geometry, st_point((b.bbox.xmin + b.bbox.xmax) / 2, (b.bbox.ymin + b.bbox.ymax) / 2))
            ) TO '{output}' (FORMAT parquet, COMPRESSION zstd)
            """
        )
        return con.execute(f"SELECT count(*) FROM '{output}'").fetchone()[0]

    return {kind: extract(kind) for kind in TYPES}


def download_base(release: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    counts = extract_base(release, OUTPUT_DIR)
    logger.info("base: %s", ", ".join(f"{kind} {count}" for kind, count in counts.items()))
    empty = [kind for kind, count in counts.items() if count == 0]
    if empty:
        raise RuntimeError(f"release {release} has no {', '.join(empty)} in Japan")
