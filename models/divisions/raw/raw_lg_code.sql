{# Queria の lg_code（総務省の全国地方公共団体コード）。pipelines/divisions.py が取り出して
   data/divisions/lg_code.parquet に保存したものを、そのまま読む。 #}

select *
from read_parquet('data/divisions/lg_code.parquet')
