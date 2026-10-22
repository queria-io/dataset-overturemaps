"""Overture Maps の divisions テーマから日本の行政区画を取り出す。

division（区画の代表点と階層）と division_area（区画のポリゴン）の 2 つを取る。
どちらも国コードを持つので country = 'JP' で絞る。

Overture の区画は市区町村コードを持たない。dbt のマートで地方公共団体コードを
名前の照合で付けるので、照合相手の一覧を Queria の lg_code データセットから取る。
コードの正本は総務省の一覧で、lg_code はそれを Queria に載せたもの。

出力:
- data/divisions/division.parquet（1行 = 1区画、日本の国から字まで）
- data/divisions/division_area.parquet（1行 = 1ポリゴン）
- data/divisions/lg_code.parquet（都道府県・市区町村の団体コードと名称）

データソース: Overture Maps Foundation
https://docs.overturemaps.org/guides/divisions/
"""

import logging
import os
from pathlib import Path

import queria

from pipelines.places import BUCKET, JAPAN_BBOX, connect_overture

logger = logging.getLogger("pipelines")

OUTPUT_DIR = Path("data/divisions")

LG_CODE_TABLE = "lg_code.main.mart_lg_code"


def extract_divisions(release: str, output_dir: Path) -> tuple[int, int]:
    base = f"s3://{BUCKET}/release/{release}/theme=divisions"
    con = connect_overture()

    counts = []
    for kind in ("division", "division_area"):
        output = output_dir / f"{kind}.parquet"
        con.execute(
            f"""
            COPY (
                SELECT *, '{release}' AS release
                FROM read_parquet('{base}/type={kind}/*.parquet', hive_partitioning = false)
                WHERE bbox.xmin BETWEEN {JAPAN_BBOX['xmin']} AND {JAPAN_BBOX['xmax']}
                  AND bbox.ymin BETWEEN {JAPAN_BBOX['ymin']} AND {JAPAN_BBOX['ymax']}
                  AND country = 'JP'
            ) TO '{output}' (FORMAT parquet, COMPRESSION zstd)
            """
        )
        counts.append(con.execute(f"SELECT count(*) FROM '{output}'").fetchone()[0])
    return counts[0], counts[1]


def extract_lg_code(output: Path, storage: str = queria.DEFAULT_STORAGE) -> int:
    # ビルドの読み出しは queria-build を名乗る（profiles.yml の custom_user_agent と同じ理由）
    con = queria.connect(storage, user_agent=os.environ.get("QUERIA_USER_AGENT") or None)
    con.execute(
        f"""
        COPY (
            SELECT lg_code, pref_code, prefecture, city, code_type
            FROM {LG_CODE_TABLE}
        ) TO '{output}' (FORMAT parquet)
        """
    )
    return con.sql(f"SELECT count(*) FROM '{output}'").fetchone()[0]


def download_divisions(release: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    divisions, areas = extract_divisions(release, OUTPUT_DIR)
    logger.info("divisions: %d divisions, %d areas", divisions, areas)
    if divisions == 0:
        raise RuntimeError(f"release {release} has no division in Japan")
    codes = extract_lg_code(OUTPUT_DIR / "lg_code.parquet")
    logger.info("divisions: %d local government codes", codes)
