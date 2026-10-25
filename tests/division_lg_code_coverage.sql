{# 地方公共団体コードの市区町村（約 1,740）と政令市の区（約 175）のうち、Overture の区画と照合
   できたものが少なすぎたら落とす。一覧の名前の書き方や Overture の階層の組み方が変わったときに、
   コードの付かない区画を黙って公開しないため。区は市区町村と分けて数える。合わせた件数の
   下限だけでは、区の照合が全部外れても（lg_code が区の行を持たない・区の名前の組み方が変わった）
   市区町村の件数だけで通ってしまう。
   リリース 2026-10-21.0 で試したときは、照合できなかった市区町村は北方領土の 6 村（照合から外している）と、
   Overture に区画の無い飛騨市だった。一つの市の区だけが合わない取りこぼし（区の再編で一覧と
   Overture の片方が古いとき）は、この件数の下限では検出できない。 #}

select
    count(distinct local_government_code) filter (where subtype = 'locality') as matched_municipality,
    count(distinct local_government_code) filter (where subtype = 'macrohood') as matched_ward
from {{ ref('division') }}
where is_municipality
having count(distinct local_government_code) filter (where subtype = 'locality') < 1700
    or count(distinct local_government_code) filter (where subtype = 'macrohood') < 160
