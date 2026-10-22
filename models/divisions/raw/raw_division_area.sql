{# Overture Maps divisions の division_area のうち country = 'JP' のもの。Overture のスキーマのまま全列を持つ。
   pipelines/divisions.py が最新リリースから取り出して data/divisions/division_area.parquet に保存する。
   範囲で絞るクエリが行グループの統計で読み飛ばせるよう、ヒルベルト曲線の順に並べて書く。 #}

select *
from read_parquet('data/divisions/division_area.parquet')
order by st_hilbert(bbox.xmin, bbox.ymin, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
