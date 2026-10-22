{# Overture Maps transportation の connector（区間どうしがつながる点）のうち、
   raw_segment の道路が参照しているもの。Overture のスキーマのまま全列を持つ。 #}

select c.*
from read_parquet('data/transportation/connector.parquet') as c
where c.id in (select unnest(connectors).connector_id from {{ ref('raw_segment') }})
order by st_hilbert(c.bbox.xmin, c.bbox.ymin, {'min_x': 122.0, 'min_y': 20.0, 'max_x': 154.5, 'max_y': 46.0}::box_2d)
