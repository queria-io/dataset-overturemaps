{# 中分類のコードは大分類の範囲に入る。範囲は日本標準産業分類（第14回改定）の大分類と中分類の対応 #}

with major_range(industry_major_code, code_from, code_to) as (
    values
        ('A', '01', '02'), ('B', '03', '04'), ('C', '05', '05'), ('D', '06', '08'),
        ('E', '09', '32'), ('F', '33', '36'), ('G', '37', '41'), ('H', '42', '49'),
        ('I', '50', '61'), ('J', '62', '67'), ('K', '68', '70'), ('L', '71', '74'),
        ('M', '75', '77'), ('N', '78', '80'), ('O', '81', '82'), ('P', '83', '85'),
        ('Q', '86', '87'), ('R', '88', '96'), ('S', '97', '98'), ('T', '99', '99')
)

select category.*
from {{ ref('category') }} as category
left join major_range using (industry_major_code)
where category.industry_code is not null
  and (
      category.industry_major_code is null
      or category.industry_code not between major_range.code_from and major_range.code_to
  )
