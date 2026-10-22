{# 日本の行政区画のポリゴンに、divisions.division の名前と地方公共団体コードを付けたもの。
   1行が1ポリゴンで、division_id が division の区画を指す。 #}

select
    area.id as area_id,
    area.division_id,
    area.subtype,
    area.class,
    division.name,
    division.prefecture,
    division.pref_code,
    division.lg_code,
    division.is_municipality,
    area.is_land,
    area.is_territorial,
    area.geometry,
    area.release
from {{ ref('raw_division_area') }} as area
left join {{ ref('division') }} as division using (division_id)
order by st_hilbert(area.bbox.xmin, area.bbox.ymin, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
