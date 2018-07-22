create view Q4a1
as
select max(year)
from musiccd m,musicgroup g 
where m.id = g.id and g.name = 'rolling stone'
;
create view Q4a
as
select title
from musiccd m, musicgroup g
where m.id= g.id and g.name = 'rolling stone' and m.year = max
;
