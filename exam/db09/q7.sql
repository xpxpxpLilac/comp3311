drop view if exists q7;
create view q7
as
select * from 
(select count(*) from beers) as nbeers,
(select count(*) from brewers) as nbrewers,
(select count(*) from users) as nusers
;
