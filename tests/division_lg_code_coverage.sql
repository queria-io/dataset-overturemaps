{# 地方公共団体コードの市区町村（政令市の区を含めて約 1,900）のうち、Overture の区画と照合
   できたものが少なすぎたら落とす。一覧の名前の書き方や Overture の階層の組み方が変わったときに、
   コードの付かない区画を黙って公開しないため。
   リリース 2026-10-21.0 で試したときは、照合できなかったのは北方領土の 6 村（照合から外している）と、
   Overture に区画の無い飛騨市くらいだった。 #}

select count(distinct lg_code) as matched
from {{ ref('division') }}
where is_municipality
having count(distinct lg_code) < 1850
