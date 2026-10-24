{# 地方公共団体コードの市区町村（約 1,740。今の lg_code は政令市の区を持たない）のうち、Overture の区画と照合
   できたものが少なすぎたら落とす。一覧の名前の書き方や Overture の階層の組み方が変わったときに、
   コードの付かない区画を黙って公開しないため。
   リリース 2026-10-21.0 で試したときは、照合できなかったのは北方領土の 6 村（照合から外している）と、
   Overture に区画の無い飛騨市だった。一つの市の区だけが合わない取りこぼし（区の再編で一覧と
   Overture の片方が古いとき）は、この件数の下限では検出できない。 #}

select count(distinct local_government_code) as matched
from {{ ref('division') }}
where is_municipality
having count(distinct local_government_code) < 1700
