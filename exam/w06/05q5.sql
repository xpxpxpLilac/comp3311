CREATE OR REPLACE FUNCTION 
	newFlight() returns trigger
as 
$$
declare
	ns integer;
begin
	select id into ns from airports where id = new.source;
	if(not found)then
		raise exception 'invalid sourse %d',new.source;
	end if;
	select id into ns from airports where id = new.dest;
	if(not found)then
		raise exception 'invalid dest %d',new.dest;	
	end if;
	select nseats into ns from planes where id = new.plane; 
	if(not found)then
		raise exception 'invalid plane %d',new.plane;
	end if;
	new.avSeats = ns;
	return new;
end;
$$ language plpgsql
;
CREATE TRIGGER addNewFlight
BEFORE
INSERT ON FLIGHTS
FOR EACH ROW
EXECUTE PROCEDURE newflight();


CREATE or replace function 
	newBook() returns trigger
as
$$
declare
	ns integer;
begin
	select avSeats into ns from flights where id = new.flight;
	ns = ns -1;
	update flights
	set avSeats = ns
	where id = new.flight;
	return new;
end;
$$ language plpgsql
;
CREATE TRIGGER addNewBooking
AFTER INSERT ON BOOKINGS
FOR EACH ROW
EXECUTE PROCEDURE newBook();


CREATE OR REPLACE function
	delBook() returns trigger
as
$$
declare
	ns integer;
begin
	select avSeats into ns from flights where id = old.flight;
	ns = ns +1;
	update flights set avseats = ns where id = old.flight;
	return old;
end;
$$language plpgsql
;
create trigger deleteBooking 
after delete on bookings
for each row
execute procedure delbook();
