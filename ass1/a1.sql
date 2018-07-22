-- COMP3311 18s1 Assignment 1
-- Written by Yuexuan Liu (z5093599), April 2018

-- Q1: ...

create or replace view Q1(unswid, name)
as
--... one SQL statement, possibly using other views defined by you ...
SELECT unswid, name
FROM People join (
		SELECT student
		FROM course_enrolments 
		GROUP BY student
		HAVING count(*)> 65) AS s
ON id = s.student
ORDER BY unswid 
;

-- Q2: ...

create or replace view Q2(nstudents, nstaff, nboth)
as
--... one SQL statement, possibly using other views defined by you ...
SELECT * FROM 
(SELECT count(id) FROM students) AS V,
(SELECT count(id) FROM staff) AS X,
(SELECT count(students.id) 
FROM students join staff 
ON students.id = staff.id) AS Y
;

-- Q3: ...
create or replace view help3(name, ncourses)
as
SELECT name, count(course)
FROM course_staff left outer join people on people.id = staff
	and role = (SELECT id FROM staff_roles where name = 'Course Convenor')
GROUP BY staff, name
;

create or replace view Q3(name, ncourses)
as
--... one SQL statement, possibly using other views defined by you ...
SELECT *
FROM help3
WHERE ncourses = (SELECT max(ncourses) FROM help3)
;

-- Q4: ...
create or replace view help4(semid)
as
SELECT id FROM semesters
WHERE year = 2005 and term = 'S2';

create or replace view findCSE
as
SELECT id FROM orgunits
WHERE longname = 'School of Computer Science and Engineering'
;
create or replace view CSEProgram
as
SELECT id FROM programs
WHERE offeredby = (SELECT * FROM findCSE)
;
create or replace view Q4a(id)
as
--... one SQL statement, possibly using other views defined by you ...
SELECT unswid 
FROM (SELECT student FROM program_enrolments
			WHERE program IN (SELECT id FROM programs WHERE code = '3978')
				and semester = (SELECT * FROM help4)) as a join people 
ON people.id = student
;


create or replace view Q4b(id)
as
--... one SQL statement, possibly using other views defined by you ...
SELECT unswid
FROM (SELECT student FROM program_enrolments
	WHERE id in (SELECT partof FROM stream_enrolments
			WHERE stream IN (SELECT id FROM streams
					WHERE code = 'SENGA1'))
	and semester = (SELECT * FROM help4)) as a join people
ON people.id = student 
;
--create or replace view findCSE
--as
--SELECT id FROM orgunits 
--WHERE longname = 'School of Computer Science and Engineering'
--;

--create or replace view CSEProgram
--as
--SELECT id FROM programs
--WHERE offeredby = (SELECT * FROM findCSE)
--;


create or replace view Q4c(id)
as
--... one SQL statement, possibly using other views defined by you ...
SELECT distinct unswid 
FROM (SELECT student FROM program_enrolments
	WHERE program IN (SELECT * FROM CSEProgram)
		and semester = (SELECT * FROM help4)) as a join people
ON people.id = student
Order by unswid 
;



-- Q5: ...
create or replace view allUnitCommittee
as
SELECT id FROM orgunits
WHERE utype = (SELECT id FROM orgunit_types
		WHERE name = 'Committee')
;
create or replace view findFacultyandCount(id)
as
SELECT facultyof(A.id) 
FROM (SELECT id FROM allUnitCommittee) as A
WHERE facultyof(A.id) is not null
;

create or replace view findCom(count,id)
as
SELECT count(*), id 
FROM (select * from findFacultyandCount) as c group by id 
;
create or replace view findMax(id)
as
SELECT id 
FROM findCom
WHERE count = (SELECT max(count) FROM findCom) 
;
create or replace view Q5(name)
as
--... one SQL statement, possibly using other views defined by you ...
SELECT longname FROM orgunits
WHERE id = (SELECT max(id) from findMax)
;

-- Q6: ...

create or replace function Q6(integer) returns text
as
$$
--... one SQL statement, possibly using other views defined by you ...
SELECT name FROM people 
WHERE $1 = people.id or $1 = people.unswid 
$$ language sql
;

-- Q7: ...
create or replace view numOfLiC
as
SELECT id FROM staff_roles
WHERE name = 'Course Convenor'
;

create or replace function Q7(text)
	returns table (course text, year integer, term text, convenor text)
as $$
--... one SQL statement, possibly using other views defined by you ...
SELECT code::TEXT, s.year, s.term::TEXT, p.name::TEXT
FROM semesters as s, people as p,
	(SELECT code,semester,staff
	FROM course_staff as cs,
		(SELECT code, id as courseid, semester
		FROM courses,
			(SELECT code,id as subjid
			FROM subjects 
			WHERE code = $1) as A
		WHERE A.subjid = courses.subject) as C
	WHERE cs.course = C.courseid and role = (SELECT * from numOfLiC)) as e
WHERE e.staff = p.id and s.id = semester
$$ language sql
;

-- Q8: ...

create or replace function Q8(integer)
	returns setof NewTranscriptRecord
as $$
declare
        rec NewTranscriptRecord;
        UOCtotal integer := 0;
        UOCpassed integer := 0;
        wsum integer := 0;
        wam integer := 0;
        x integer;
begin
        select s.id into x
        from   Students s join People p on (s.id = p.id)
        where  p.unswid = $1;
        if (not found) then
                raise EXCEPTION 'Invalid student %',_sid;
        end if;
        for rec in
                select su.code,
                         substr(t.year::text,3,2)||lower(t.term),
			 prog.code,
                         substr(su.name,1,20),
                         e.mark, e.grade, su.uoc
                from   People p
                         join Students s on (p.id = s.id)
                         join Course_enrolments e on (e.student = s.id)
                         join Courses c on (c.id = e.course)
                         join Subjects su on (c.subject = su.id)
                         join Semesters t on (c.semester = t.id)
			 join program_enrolments pe on (pe.student = s.id and pe.semester = t.id)
			 join programs prog on (pe.program = prog.id)
                where  p.unswid = $1
                order  by t.starting, su.code
        loop
                if (rec.grade = 'SY') then
                        UOCpassed := UOCpassed + rec.uoc;
                elsif (rec.mark is not null) then
                        if (rec.grade in ('PT','PC','PS','CR','DN','HD','A','B','C')) then
                                -- only counts towards creditted UOC
                                -- if they passed the course
                                UOCpassed := UOCpassed + rec.uoc;
                        end if;
                        -- we count fails towards the WAM calculation
                        UOCtotal := UOCtotal + rec.uoc;
                        -- weighted sum based on mark and uoc for course
                        wsum := wsum + (rec.mark * rec.uoc);
                        -- don't give UOC if they failed
                        if (rec.grade not in ('PT','PC','PS','CR','DN','HD','A','B','C')) then
                                rec.uoc := 0;
                        end if;

                end if;
                return next rec;
        end loop;
        if (UOCtotal = 0) then
                rec := (null,null,null,'No WAM available',null,null,null);
        else
                wam := wsum / UOCtotal;
                rec := (null,null,null,'Overall WAM',wam,null,UOCpassed);
        end if;
        -- append the last record containing the WAM
        return next rec;
end;
$$ language plpgsql
;


-- Q9: ...




create or replace function getPattern(integer)
	returns table(pattern text)
as $$
declare
	longp TextString;
begin
	SELECT definition into longp
	FROM acad_object_groups
	WHERE id = $1 and gdefby = 'pattern' and definition !~ '[;{}/]';
	SELECT regexp_replace(longp,'(#|x)','.','g') into longp;
	return query SELECT * FROM regexp_split_to_table(longp,',');

end;	
$$ language plpgsql
;

create or replace function Q9(integer)
	returns setof AcObjRecord
as $$
declare
	co integer;
	p text;
	subcode char(8);
	pat text;
	r AcObjRecord;
begin
	SELECT count(*) into co FROM (SELECT * FROM getPattern($1)) as n;
	if(co = 1) then
		SELECT pattern into p FROM (SELECT * FROM getpattern($1)) as V;
		if(p ~* '(FREE|GEN)') then
			r.objtype = 'subject';
			r.object = p;
			return next r;
		end if;
	end if;
	if(co = 0) then
		return;
	else
		
		for subcode in
			SELECT pattern as pn FROM getPattern($1)
			WHERE pattern ~* '[A-Z]{4}[0-9]{4}' 
		loop
			return query SELECT text(a.gtype), text(s.code) FROM acad_object_groups as a, subjects as s
                                                        WHERE a.id = $1 and s.code = subcode;
		end loop;
		for subcode in
			SELECT code FROM subjects
			WHERE code NOT IN (SELECT pattern as pn FROM getPattern($1) 
						WHERE pattern ~* '^[A-Z]{4}[0-9]{4}$')
		loop
			for pat in
				SELECT pattern FROM getPattern($1) 
				WHERE pattern !~* '[A-Z]{4}[0-9]{4}' 
			loop
				if(subcode ~* pat) then
					return query SELECT text(a.gtype), text(s.code) FROM acad_object_groups as a, subjects as s
							WHERE a.id = $1 and s.code = subcode;
				end if;
			end loop;
		end loop;
	end if;		
	
end;
$$ language plpgsql
;

