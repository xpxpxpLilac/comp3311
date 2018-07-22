-- COMP3311 12s1 Exam Q6
-- The Q6 view must have attributes called
-- (location,date,team1,goals1,team2,goals2)

drop view if exists teamscore;
create view teamscore
as
select g.scoredin as match, t.country as team, count(*) as num
from goals g join players p on g.scoredby = p.id
	join teams t on t.id = p.memberof
group by t.country,g.scoredin 
;

drop view if exists matchteam;
create view matchteam
as
select i.match as match, t.country as team
from involves i join teams t on t.id = i.team
;

drop view if exists matchteamscore;
create view matchteamscore
as
select m.match as match, m.team as team , coalesce(ts.num,0) as num
from matchteam m left outer join teamscore ts on m.team = ts.team and m.match = ts.match 
;

drop view if exists twogoal;
create view twogoal
as
select ms1.match, ms1.team as team1, ms1.num as goal1, ms2.team as team2, ms2.num as goal2
from matchteamscore ms1 join matchteamscore ms2 on ms1.match = ms2.match and ms1.team < ms2.team
;
drop view if exists Q6;
create view Q6
as
select m.city as location, m.playedon as date, t.team1 as team1, t.goal1 as goals1,t.team2 as team2,t.goal2 as goals2 
from matches m join twogoal t on m.id = t.match
;
