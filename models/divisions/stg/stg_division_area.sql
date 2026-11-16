{# raw_division_area の列を選んだもの。並べ替えに使う bbox も持つ。 #}

select
    id as area_id,
    division_id,
    subtype,
    class,
    is_land,
    is_territorial,
    geometry,
    release,
    bbox
from {{ ref('raw_division_area') }}
