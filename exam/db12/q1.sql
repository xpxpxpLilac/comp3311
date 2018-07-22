-- COMP3311 12s1 Exam Q1
-- The Q1 view must have attributes called (team,matches)

drop view if exists Q1;
create view Q1
as
SELECT T.country as team, count(*) as matches
FROM teams T left join involves I ON T.id = I.team
GROUP BY T.country  
;
