"""Overture Maps データパイプライン。

最新リリースを 1 度だけ決め、すべてのテーマを同じリリースから取る。

1. places: 日本の POI を取り出す
2. transportation: 日本の道路網を取り出す
3. divisions: 日本の行政区画と、照合に使う地方公共団体コードを取り出す
4. dbt: dbt ビルド
"""

import logging

from dbt.cli.main import dbtRunner

from pipelines.divisions import download_divisions
from pipelines.places import download_places, latest_release
from pipelines.transportation import download_transportation

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("pipelines")


def dbt_build():
    dbt = dbtRunner()
    for command in (["deps"], ["build"], ["docs", "generate"]):
        result = dbt.invoke(command)
        if not result.success:
            raise SystemExit(f"dbt {' '.join(command)} failed")


def main():
    # テーマごとに一覧し直すと、その間に新しいリリースが出たときにテーマごとに
    # 別々のリリースになる
    release = latest_release()
    logger.info("Overture release %s", release)

    logger.info("1/4: places (Overture Maps 日本の POI)")
    download_places(release)

    logger.info("2/4: transportation (Overture Maps 日本の道路網)")
    download_transportation(release)

    logger.info("3/4: divisions (Overture Maps 日本の行政区画)")
    download_divisions(release)

    logger.info("4/4: dbt build")
    dbt_build()


if __name__ == "__main__":
    main()
