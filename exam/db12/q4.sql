-- COMP3311 12s1 Exam Q4
-- The Q4 view must have attributes called (team1,team2,matches)

drop view if exists Q4;
create view Q4
as
select team1,team2, matches from
helper
where matches = (select max(matches) from helper)
;
drop view if exists helper;
create view helper
as
select t1.country as team1 ,t2.country as team2, count(*) as matches
from h4 t1, h4 t2
where t1.match = t2.match and t1.country < t2.country
group by t1.country,t2.country
;
drop view if exists h4;
create view h4
as
select I.match, T.country
from involves I join matches M on I.match = M.id
		join teams T on T.id = I.team 
;

