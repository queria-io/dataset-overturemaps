{# Overture Maps buildings の building のうち日本の範囲に入るもの。Overture のスキーマのまま全列を持つ。
   pipelines/buildings.py が最新リリースから取り出して data/buildings/building.parquet に保存する。
   範囲で絞るクエリが行グループの統計で読み飛ばせるよう、ヒルベルト曲線の順に並べて書く。 #}

select *
from read_parquet('data/buildings/building.parquet')
order by st_hilbert(bbox.xmin, bbox.ymin, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
