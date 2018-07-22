CREATE or replace FUNCTION 
	insertWinner() returns trigger
as
$$
declare
	ns integer;
begin
	select nWinners into ns from oscar where id = new.oscar;
	ns = ns + 1;
	update oscar set nwinners= ns where id = new.oscar;
	return new;
end;
$$plpgsql;

create trigger insertnewwinner
after insert on winner
for each row 
execute procedure insertWinner();

create or replace function
	insertActor() returns trigger
as
$$
declare
	gender char(1);
begin
	select p.gender into gender from winner w join person p on w.person = p.id where p.id = new.person; 
	if(not found)then
		raise exception 'Invalid person %d',new.person;
	end if;
	if(gender = 'M')then
		raise excpetion 'Wrong gender for best actress'; 
	end if;
	return new;
end;
$$ plpgsql
;

create trigeer insertfemalewinner
before insert on winner
for each row
execute procedure insertActor();


create or replace function
	insertDirWinner() returns trigger
as
$$
declare
	ns integer;
begin
	select person into ns from director where movie = new.movie;
	if(not found)then
		raise exception 'Invalid movie';
	end if;
	if(ns != new.person)then
		raise exception 'Invalid director';
	end if; 
	select yearmade into ns from movie where id = new.movie;
	if(ns != new.year and ns != new.year-1)then
		raise exception 'Invalid year';
	end if;
	return new;
end;
$$ plpgsql 
;

create trigger insertbestDir
before insert on winner  
for each row
execute procedure insertDirWinner();
