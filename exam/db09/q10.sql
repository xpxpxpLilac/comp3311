drop view if exists allbrew;
create view allbrew
as
select distinct bs.id
from beers b join brewers bs on b.brewer = bs.id
;
drop view if exists nobrew;
create view nobrew
as
select bs.id as id, name
from brewers bs
where bs.id not in (select * from allbrew)
;
drop view if exists q10;
create view q10
as
select n.name as brewer,l.country as country
from nobrew n join brewers bs on bs.id = n.id
 		join locations l on bs.location = l.id 
;
