drop view if exists q8;
create view q8
as
select l.country as country, count(*)
from brewers b join locations l on b.location = l.id
group by l.country
having count(*)>20
;
