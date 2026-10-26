{# Overture の basic_category のうち category の表（reference/places/category.csv）に行の無いものが増えたら落とす。
   Overture は分類を足したり名前を変えたりするので、対応表に無い分類は産業分類と無人の設備かが
   黙って NULL になる。1 万件を超える分類が対応表から漏れたら、表に行を足す。
   落ちたときの行が、対応表に足す分類とその件数。 #}

with category as (
    select distinct basic_category from {{ ref('category') }}
)

select place.basic_category, count(*) as places
from {{ ref('place') }} as place
anti join category using (basic_category)
where place.basic_category is not null
group by place.basic_category
having count(*) > 10000
