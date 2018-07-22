-- COMP3311 12s1 Exam Q3
-- The Q3 view must have attributes called (team,players)

drop view if exists Q3;
create view Q3
as
select * from
helper
where players = (select max(players) from helper)
;
drop view if exists helper;
create view helper
as
select T.country as team, count(*) as players
from players P join teams T on P.memberof = T.id
where P.id not in (select scoredby from goals)
group by T.country
;

