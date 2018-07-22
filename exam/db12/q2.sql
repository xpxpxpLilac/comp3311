-- COMP3311 12s1 Exam Q2
-- The Q2 view must have one attribute called (player,goals)

drop view if exists Q2;
create view Q2
as
SELECT P.name as player, count(*) as goals 
FROM goals G left join players P ON G.scoredBy = P.id
WHERE rating = 'amazing'
GROUP BY p.name
HAVING COUNT(*)> 1
;

