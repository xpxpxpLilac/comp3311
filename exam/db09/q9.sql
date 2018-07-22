drop view if exists q9h;
create view q9h
as
select l.country as country, count(distinct b.style) as num
from beers b join brewers bs on b.brewer = bs.id
	join locations l on bs.location = l.id
	join beerstyles bty on b.style = bty.id 
group by l.country
;
drop view if exists q9;
create view q9
as
select country, num as nstyles
from q9h
where num = (select max(num) from q9h)
;
