{# 日本の建物の部分（高層部・低層部など）。1行が1部分で、building_id が buildings.building を指す。 #}

select * exclude (bbox)
from {{ ref('stg_building_part') }}
order by st_hilbert(bbox.xmin, bbox.ymin, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
