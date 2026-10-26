{# place の Overture Maps の分類から、日本標準産業分類（第14回改定）・OpenStreetMap のタグ・無人の設備かへの
   対応表。正本は reference/places/category.csv で、Queria が分類の名前と中身から手で当てたもの。
   basic_category ごとの既定の行（taxonomy_primary が NULL）と、その中で行き先の違う taxonomy_primary
   だけの行がある。place には付けず、使う側がこの表と JOIN する #}

select
    basic_category,
    taxonomy_primary,
    industry_major_code,
    industry_code,
    osm_tag,
    cast(is_unattended as boolean) as is_unattended
from read_csv('reference/places/category.csv', header = true, all_varchar = true)
order by basic_category, taxonomy_primary nulls first
