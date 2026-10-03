{# Overture Maps places の日本分。
   pipelines/places.py が最新リリースから取り出して data/places/place.parquet に保存する。
   近い場所の行が同じ行グループに入るよう、ヒルベルト曲線の順に並べて書く。
   範囲で絞るクエリが行グループの統計で読み飛ばせるようになる。 #}

select
    *,
    st_point(lon, lat) as geometry
from read_parquet('data/places/place.parquet')
order by st_hilbert(lon, lat, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
