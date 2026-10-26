{# 1 つの分類に行が 2 つあると、引いた側の行が増える #}

select basic_category, taxonomy_primary, count(*) as rows
from {{ ref('category') }}
group by basic_category, taxonomy_primary
having count(*) > 1
