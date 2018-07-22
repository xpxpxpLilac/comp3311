drop view if exists userlike;
create view userlike
as
select u.id as userid, b.style as style, count(*)
from ratings r join beers b on r.beerid = b.id
	join users u on u.id = r.userid
where r.rating > 6
group by userid, style
having count(*)> 2
;

drop view if exists q11;
create view q11
as
select u.name as user, bs.name as style
from userlike ul join users u on ul.userid = u.id
	join beerstyles bs on bs.id = ul.style
;

