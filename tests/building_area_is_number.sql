{# 建築面積が数として取れていない建物があれば落とす。st_area_spheroid に経度・緯度の順の
   座標を渡すと黙って NaN を返すので、座標の順を取り違えたときに気づけるようにする。 #}

select building_id, area_m2
from {{ ref('building') }}
where area_m2 is null or isnan(area_m2) or area_m2 <= 0
