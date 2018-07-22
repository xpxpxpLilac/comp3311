-- COMP3311 12s1 Exam Q5
-- The Q5 view must have attributes called (team,reds,yellows)
drop view if exists CardsFor;
create view CardsFor
as
select t.country as team, c.cardtype as card, count(*) as num
from cards c join players p on p.id = c.givento
		join teams t on t.id = p.memberof 
group by team,card
;

drop view if exists redcardfor;
create view redcardfor
as
select team, card, num
from cardsfor
where card = 'red'
;

drop view if exists redcard;
create view redcard
as
select t.country as team, coalesce(r.num,0) as num
from teams t left outer join redcardfor r on t.country = r.team
;

drop view if exists yecardfor;
create view yecardfor
as
select team, card, num
from cardsfor
where card = 'yellow'
;

drop view if exists yecard;
create view yecard
as
select t.country as team, coalesce(r.num,0) as num
from teams t left outer join yecardfor r on t.country = r.team
;
drop view if exists Q5;
create view Q5
as
select r.team, r.num, y.num
from redcard r, yecard y
where r.team = y.team
;
