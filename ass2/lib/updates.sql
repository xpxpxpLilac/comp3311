-- COMP3311 18s1 Assignment 2
--
-- updates.sql
--
-- Written by Y.Liu, May 2018

--  This script takes a "vanilla" MyMyUNSW database and
--  make all of the changes necessary to make the databas
--  work correctly with your PHP scripts.
--  
--  Such changes might involve adding new tables, views,
--  PLpgSQL functions, triggers, etc. Other changes might
--  involve dropping existing tables or redefining existing
--  views and functions
--  
--  Make sure that this script does EVERYTHING necessary to
--  upgrade a vanilla database; if we need to chase you up
--  because you forgot to include some of the changes, and
--  your system will not work correctly because of this, you
--  will receive a 3 mark penalty.

---------------type define -----------------------------------------------
create type aog as (id int, gdefby AcadObjectGroupDefType, definition TextString);
create type pro_pair as (id integer, code char(4));
create type rules_series as (ruleid int, type text, min int, max int);
create type new_rules_series as (ruleid int, type text, min int, max int,ao_group int);
create type rules_course as (code text,prereq_rid int,exclude int);


---given a F=SCI like string-------------
create or replace function
	findF(text) returns table(code text)
as
$$
declare
	s text;
	k int;
	i int;
	j int;
	node integer[];
begin
	SELECT regexp_replace($1,'F=','') into s;
	SELECT id into k FROM orgunits WHERE unswid = s;
	node = array_append(node,k);
	foreach i in ARRAY node
	loop
		for j in 
			SELECT member FROM orgunit_groups WHERE owner = i
		loop
			node = array_append(node,j);
			return query SELECT DISTINCT s.code::text FROM subjects as s WHERE s.offeredBy = j;  
		end loop;
	end loop;
end;
$$ language plpgsql
;

--do a string as a query----
create or replace function 
	dodefinitionsql(integer) returns setof pro_pair
as
$$
declare
	r text;
begin
	SELECT definition into r
	FROM acad_object_groups
	WHERE id = $1;
	return query execute r; 
end;
$$language plpgsql
;

--get pattern from program--
create or replace function
	getdefinition(integer) returns setof text
as
$$
declare
	longp TextString;
begin	
	SELECT definition into longp
	FROM Acad_object_groups
	WHERE id = $1;
	return query SELECT * FROM regexp_split_to_table(longp,',');
end;
$$ language plpgsql
;

create or replace function
	getSubPat(integer) returns setof text
as
$$
declare
	longp text;
	r text;
	k text;
	a text[];
begin
	SELECT definition into longp FROM Acad_object_groups
	WHERE id = $1;
--	SELECT regexp_replace(longp,'#','.','g') into longp;
	SELECT regexp_replace(longp,'({|})','','g') into longp;
        SELECT regexp_replace(longp,';',',','g') into longp;
	for r in
		SELECT * FROM regexp_split_to_table(longp,',')
	loop
		if(r ~ '^(FREE|GEN#|GENG|####)' or r ~ '(all|ALL)')then
			return next r;
		elsif (r ~ '^[A-Z]{4}[0-9]{4}$') then
			return next r;
		else
			SELECT regexp_replace(r,'#','.','g') into r;
			if(r ~ 'F=')then
				if(r ~ '^F=[A-Z]{3,}$') then
					return next r;
				elsif(r ~ '^[A-Z0-9.]{8}/F=[A-Z]{3,}') then
					SELECT regexp_split_to_array(r,'/') into a;
					for k in 
						SELECT code FROM findF(a[2]) WHERE code ~ a[1]
					loop
						return next k;
					end loop;
				else
                                        SELECT regexp_replace(r,'\.','#','g') into r;
					return next r;
				end if;
			else
				for k in
					SELECT s.code FROM subjects as s
					WHERE s.code ~ r
				loop
					return next k;
				end loop;
			end if;
		end if;
	end loop;
end;
$$ language plpgsql
;
--get enumerated programs-----
create or replace function
	p_emufinder(integer) returns setof text
as
$$
declare
	r text;
begin
	for r in
		SELECT p.code  
		FROM programs as p 
		WHERE id IN (SELECT program
			     FROM program_group_members
			     WHERE ao_group = $1)
		ORDER BY p.code
	loop
		return next r;
	end loop;  
end;
$$ language plpgsql
;
--get enumerated streams----
create or replace function
	stream_emufinder(integer) returns setof text
as
$$
declare
	r text;
begin
	for r in
		SELECT s.code
		FROM streams as s
		WHERE id IN (SELECT stream
			     FROM Stream_group_members
			     WHERE ao_group = $1)
		ORDER BY s.code
	loop
		return next r;
	end loop;
end;
$$
language plpgsql
;
--get enumerated subjects-----
create or replace function
	subject_emufinder(integer) returns setof text
as
$$
declare
	r text;
	k text;
begin
	for r in 
		SELECT s.code
		FROM subjects as s 
		WHERE id IN (SELECT subject
			     FROM subject_group_members
			     WHERE ao_group = $1)
		ORDER BY s.code
	loop
		return next r;
	end loop;
	for r in
		SELECT id 
		FROM acad_object_groups
		WHERE parent = $1
	loop
		for k in
			SELECT s.code
			FROM subjects as s
			WHERE id IN (SELECT subject
				     FROM subject_group_members
				     WHERE ao_group = r::integer)
			ORDER BY s.code
		loop
			return next k;
		end loop;
	end loop;
end;
$$ language plpgsql
;

create or replace function
	s_patfinder(integer) returns setof text
as
$$
declare
	r int;
begin
	for r in
		SELECT * FROM getdefinition($1)
	loop
	end loop;
end;
$$ language plpgsql
;
create or replace function
	programfinder(integer) returns setof text
as
$$
declare
	r aog;
	k text;
begin
	SELECT id, gdefby, definition into r
	FROM Acad_object_groups
	WHERE id = $1;
	if(r.gdefby = 'pattern') then
		return query SELECT DISTINCT * FROM getdefinition($1) ORDER BY getdefinition;
	elsif(r.gdefby = 'query') then
		return query SELECT DISTINCT code::text FROM dodefinitionsql($1) ORDER BY code;
	else
		return query SELECT DISTINCT * FROM p_emufinder($1) ORDER BY p_emufinder;
	end if; 
end;
$$ language plpgsql
;

create or replace function 
	streamfinder(integer) returns setof text
as
$$
declare
	r aog;
begin
	SELECT id, gdefby, definition into r
	FROM acad_object_groups
	WHERE id = $1;
	return query SELECT DISTINCT * FROM stream_emufinder($1) ORDER BY stream_emufinder;
end;
$$ language plpgsql
;
 
create or replace function
	subjectfinder(integer) returns setof text
as
$$
declare
	r aog;
begin
	SELECT id ,gdefby, definition into r
	FROM acad_object_groups
	WHERE id = $1;
	if(r.gdefby = 'pattern') then
		return query SELECT DISTINCT * FROM getSubPat($1) ORDER BY getSubPat;
	else
		return query SELECT DISTINCT * FROM subject_emufinder($1) ORDER BY subject_emufinder;
	end if;
end;
$$ language plpgsql
;

create or replace function
	qone(integer) returns setof text
as
$$
declare
	r text;
begin
	SELECT gtype into r FROM acad_object_groups
	WHERE id = $1;
	if(r = 'program') then
		return query SELECT * FROM programfinder($1);
	elsif(r = 'stream')then
		return query SELECT * FROM streamfinder($1);
	else
		return query SELECT * FROM subjectfinder($1);
	end if;
end;
$$ language plpgsql
;


------------------------------Q2----------------------------------------
create or replace function
	subjectInGroup(text,integer) returns text
as
$$
declare
	k text;
	f text;
	s int;
	r text;
	a text[];
	a_1 text;
begin
	s = 0;
	for r in 
		SELECT getSubPat FROM getSubPat($2) WHERE getSubPat !~ '[A-Z]{4}[0-9]{4}'
	loop
		if(r ~ '^FREE[^/]{4}$')then
			SELECT regexp_replace(r,'FREE','####') into r;
			SELECT regexp_replace(r,'#','.','g') into r;
			if($1 !~ '^GEN' and $1 ~ r)then
--				s = 'FREE#### yes';
				s = 1;
				return s;
			end if;
		elsif(r ~ '^GEN[^/]{5,}$')then
			if(r ~ '^GENG') then
				SELECT regexp_replace(r,'GEN.','GEN#') into r;
			end if;
			SELECT regexp_replace(r,'#','.','g') into r;
			if($1 ~ r)then
--				s = 'GEN##### yes';
				s = 1;
				return s;
			end if;
		elsif(r ~ '^####[^/]{4,}$')then
                        SELECT regexp_replace(r,'#','.','g') into r;
			if($1 ~ r)then
--				s = '#### yes';
				s = 1;
				return s;
			end if;
		elsif(r ~ 'F=')then	
			SELECT regexp_replace(r,'.*/','') into f;
			if(r ~ '^(all|ALL)' or r ~ '^F=[A-Z]{3,}$')then
		                SELECT EXISTS (SELECT * FROM findF(f) WHERE code = $1) into k;
				if(k = 1)then
--					s = 'ALL|all/F= /F= yes';
					s = 1;
					return s;
				end if;
			elsif(r ~ '^GEN')then
--				s = 'GEN /F= is here';
				SELECT regexp_split_to_array(r,'/') into a;
				a_1 = a[1];
				if(r ~ '^GENG')then
					SELECT regexp_replace(a_1,'GENG','GEN#') into a_1;
				end if;
				SELECT regexp_replace(a_1,'#','.','g') into a_1;
                                SELECT EXISTS (SELECT * FROM findF(f) WHERE code = $1) into k;
				if(k = 't' and $1 ~ a_1)then
--					s = 'GEN#####/F= yes';
					s = 1;
					return s;
				end if;
			elsif(r ~ '^####')then
				SELECT regexp_split_to_array(r,'/') into a;
				SELECT regexp_replace(a[1],'#','.','g') into a_1;
                                SELECT EXISTS (SELECT * FROM findF(f) WHERE code = $1) into k;
				if(k = 't' and $1 ~ a_1)then
--					s = '####/F= yes';
					s = 1;
					return s;
				end if;
			elsif(r ~ '^FREE')then
				SELECT regexp_split_to_array(r,'/') into a;
				SELECT regexp_replace(a[1],'FREE','####') into a_1; 
	                        SELECT regexp_replace(a_1,'#','.','g') into a_1;
                                SELECT EXISTS (SELECT * FROM findF(f) WHERE code = $1) into k;
				if(k = 't' and $1 !~ '^GEN' and $1 ~ a_1)then
--					s = 'FREE####/F= yes';
					s = 1;
					return s;
				end if;	
			end if;
		end if;
	end loop;
        SELECT EXISTS (SELECT * FROM getSubPat($2) WHERE getSubPat = $1) into k;
        if(k = 't') then
--        	s = 'yes from the outside';
		s = 1;
	end if;
	return s;
end;
$$ language plpgsql
;	


create or replace function
	qtwo(text,integer) returns int
as
$$
declare
	k text;
	r int;
	t text;
	def text;
begin
	r = 0;
--	r = 'no fromthe beginning';
	SELECT gtype into t FROM acad_object_groups WHERE id = $2;
	if(t = 'program') then
--		SELECT 1 into k FROM programfinder($2) WHERE $1 IN (SELECT * FROM programfinder($2));
	        SELECT EXISTS (SELECT * FROM programfinder($2) WHERE programfinder = $1) into k;
		if(k = 't')then 
--			r = 'success program';
			r = 1; 
		end if;
	elsif(t = 'stream') then
--		SELECT 1 into k FROM streamfinder($2) WHERE $1 IN (SELECT * FROM streamfinder($2));
	        SELECT EXISTS (SELECT * FROM streamfinder($2) WHERE streamfinder = $1) into k;
		if(k = 't')then 
--			r = 'success stream'; 
			r = 1;
		end if;
	elsif(t = 'subject')then
		SELECT gdefby into def FROM acad_object_groups WHERE id = $2;
		if(def = 'pattern')then 
			SELECT * into r FROM subjectInGroup($1,$2);
		else
			SELECT EXISTS (SELECT * FROM subject_emufinder($2) WHERE subject_emufinder = $1) into k;
			if(k = 't') then r = 1;end if;
		end if;
	end if;
	return r;
end;
$$ language plpgsql
;

---------------------------------------Q3----------------------------------------------------------------------

---------check if the valid GEN##### is ingroup of the rules-------------
----(code,rule)
create or replace function
	checkGEingroup(text,int) returns int
as
$$
declare 
	r int;
	p int;
begin
	SELECT ao_group into r FROM rules WHERE id = $2;
	SELECT * into p FROM subjectInGroup($1,r);
	return p;
end;
$$ language plpgsql
;


--------check if a GenED is under the program/stream faculty--------------
--validge(code,program)
create or replace function
	validProGE(text,int) returns int
as
$$
declare
	r int;
	k int;
	s int;
	p int;
begin
	SELECT offeredby into r FROM programs WHERE id = $2;
	SELECT facultyof into k FROM facultyof(r);

	SELECT offeredby into r FROM subjects WHERE code = $1;
	SELECT facultyof into s FROM facultyof(r);
----same faculty , not valid ge--------------
	if(s = k)then
		p = 0;
	else
		p = 1;	
	end if;
	return p;
end;
$$ language plpgsql
;

create or replace function
	validStGE(text,int) returns int
as
$$
declare
	r int;
	k int;
	s int;
	p int;
begin
        SELECT offeredby into r FROM streams WHERE id = $2;
	SELECT facultyof into k FROM facultyof(r);

	SELECT offeredby into r FROM subjects WHERE code = $1;
	SELECT facultyof into s FROM facultyof(r);

	if(s = k)then
		p = 0;
	else
		p = 1;
	end if; 
	return p;
end;
$$ language plpgsql
;

--given a rule id, check ik ao_group pattern is GEN#-----
create or replace function
	checkPatGE(int) returns int
as
$$
declare
	r int;
	pat text;
	p int;
begin
	SELECT ao_group into r FROM rules WHERE id = $1;
	SELECT definition into pat FROM acad_object_groups WHERE id = r;
	if(pat ~ '^GEN')then
		p = 1;
	else 
		p = 0;	
	end if;
	return p;
end;
$$ language plpgsql
;


create or replace function
	checkType(text) returns text
as
$$
declare
	r text;
begin
	if($1 ~ '^[0-9]{4}$')then
		r = 'Program';
	elsif($1 ~ '^[A-Z]{5}[A-Z0-9]$')then
		r = 'Stream';
	elsif($1 ~ '^[A-Z]{4}[0-9]{4}$')then
		r = 'Subject';
	end if ;
	return r;
end;
$$ language plpgsql
;

--------checkRules(code, ruleid) ----------------
create or replace function
	checkRules(text, int) returns int
as
$$
declare
	r int;
	pat text;
	c text;
	t text;
	ct text;
	existence int;
	p int;
begin
	SELECT ao_group into r FROM rules WHERE id = $2;
	SELECT qone into c FROM qone(r);
	SELECT gtype into t FROM acad_object_groups WHERE id = r;
	SELECT checktype into ct FROM checkType($1);
        SELECT * into existence FROM qtwo($1,r);

	if(r is null)then
		p = 0;
	elsif(c is null)then
		p = 0;
	elsif(t !~* ct)then
		p = 0; 
	elsif(existence)then
		p = 1;
	else 
		p = 0;
	end if;
	return p;
end;
$$ language plpgsql
;


----------------------------------------------------------Q4----------------------------------------------------------
---(sid(not unswid),sem.id)
create or replace function
	getAllRules(int,int) returns setof rules_series
as
$$
declare
	i int;
	p int;
	s int;
	rules rules_series;
begin
	SELECT id,program into i,p FROM program_enrolments WHERE student = $1 and semester = $2; 
--	SELECT stream into s FROM stream_enrolments WHERE partOf = i;
	for rules in
		SELECT rule,ru.type,ru.min,ru.max  
		FROM Program_rules as pro left outer join rules as ru on pro.rule = ru.id 
		WHERE pro.program = p and ru.type IN('CC','PE','FE','GE','LR') 
	loop
		return next rules;
	end loop;
	for s in
		SELECT stream FROM stream_enrolments WHERE partOf = i
	loop
		for rules in
                	SELECT rule,ru.type,ru.min,ru.max,ao_group
                	FROM Stream_rules as st left outer join rules as ru on st.rule = ru.id
                	WHERE st.stream = s and ru.type IN('CC','PE','FE','GE','LR','RQ','WM','MR')
		loop
			return next rules;
		end loop;
	end loop; 

end;
$$ language plpgsql
;

create or replace function
	rulesRightOrder(int,int) returns table(rule rules_series)
as
$$
declare
begin
	for rule in
		SELECT * FROM getallrules($1,$2)
		ORDER BY
                        type = 'LR',type = 'GE',type = 'FE',type = 'PE',type = 'CC',ruleid
	loop
		return next;
	end loop;
end;
$$ language plpgsql
;


----update uoc if the course is being studied-----
create or replace function
	updateTrans(int,int) returns setof TranscriptRecord
as
$$
declare
        r TranscriptRecord;
begin
	for r in
                SELECT * FROM transcript($1,$2)
        loop
		if(r.grade is null and r.code is not null)then
			r.uoc = null;
		end if;
		return next r;
        end loop;
end;
$$ language plpgsql
;

------(sid(people.id),tid)----
create or replace function
	exactTerm(int,int) returns int
as
$$
declare
	curr date;
	prev int;
	target date;
	smallest int;
	largest int;
	se int;
	k text;
begin
	SELECT EXISTS (SELECT * FROM program_enrolments WHERE student = $1 and semester = $2) into k;	
	if(k = 't')then 
		return $2;
	else
		SELECT starting into target FROM semesters WHERE id = $2; 
		SELECT semester into smallest FROM program_enrolments as pe left outer join semesters as sem on pe.semester = sem.id
		WHERE student = $1
		ORDER BY sem.starting
		LIMIT 1;

                SELECT semester into largest FROM program_enrolments as pe left outer join semesters as sem on pe.semester = sem.id
                WHERE student = $1
                ORDER BY sem.starting desc
                LIMIT 1;


		SELECT starting into curr FROM semesters WHERE id = smallest;
		if(target < curr)then
			return smallest;
		end if;

                SELECT starting into curr FROM semesters WHERE id = largest;
                if(target > curr)then
                        return largest;
                end if;

		for se in
	        	SELECT semester FROM program_enrolments as pe left outer join semesters as sem on pe.semester = sem.id
                	WHERE student = $1
                	ORDER BY sem.starting
		loop
	                SELECT starting into curr FROM semesters WHERE id = se;
			if(target < curr)then
				return prev;
			else
				prev = se;
			end if;
		end loop;
	end if;
end;
$$ language plpgsql
;


--------------------------------------------------Q5---------------------------------------

-----(sid,term.id)----
create or replace function
	allRules(int,int) returns setof new_rules_series
as
$$
declare
	i int;
	p int;
	s int;
	rules new_rules_series;
begin
	SELECT id, program into i,p FROM program_enrolments WHERE student = $1 and semester = $2;
	
	for rules in
                SELECT rule,ru.type,ru.min,ru.max,ao_group
                FROM Program_rules as pro left outer join rules as ru on pro.rule = ru.id
                WHERE pro.program = p and ru.type IN('CC','PE','FE','GE','LR','RQ','WM','MR')
	loop
		return next rules;
	end loop;

	for s in
		SELECT stream FROM stream_enrolments WHERE partOf = i
	loop
		for rules in
                	SELECT rule,ru.type,ru.min,ru.max,ao_group
                	FROM Stream_rules as st left outer join rules as ru on st.rule = ru.id
                	WHERE st.stream = s and ru.type IN('CC','PE','FE','GE','LR','RQ','WM','MR')
		loop
			return next rules;
		end loop;
	end loop; 
end;
$$ language plpgsql
;

-------give right order for core courses, give MR right pattern-----







create or replace function
	rightOrder(int,int) returns setof new_rules_series
as
$$
declare
	r new_rules_series;
begin
	for r in
		SELECT * FROM allRules($1,$2) 
		ORDER BY
                        type = 'MR', type = 'WM', type = 'RQ',type = 'LR',type = 'GE',type = 'FE',type = 'PE',type = 'CC',ruleid
	loop
		return next r; 
	end loop;
end;
$$ language plpgsql
;


------(sid,term.id----------------)
create or replace function
	findCareer(int,int) returns text 
as
$$
declare
	r text;
begin
	SELECT career into r FROM programs p left outer join program_enrolments pe on p.id = pe.program
	WHERE pe.student = $1 and pe.semester = $2;
	
	return r;
end;
$$ language plpgsql
;

----transcipt into a table-
----(sid,termidexact)----------------------
create or replace function
	transTable(int,int) returns setof TranscriptRecord
as
$$
declare
	r TranscriptRecord;
begin
	for r in
		SELECT * FROM Transcript($1,$2)
	loop
		if(r.grade = 'NF' or r.grade = 'DF' or (r.uoc is not null and r.uoc = 0) or r.code is null) then
			continue;
		else
			return next r;
		end if;
	end loop;
end;
$$ language plpgsql
;

create or replace function
	uocwam(int,int) returns TranscriptRecord
as
$$
declare
	r TranscriptRecord;
begin
	for r in
		SELECT * FROM Transcript($1,$2)
	loop
	 	if(r.code is null)then
			if(r.uoc is not null and r.mark is not null)then
				return r;
			else
				r.mark = 0;
				r.uoc = 0;
				return r;
			end if;
		end if;
	end loop;
end;
$$ language plpgsql
;


-------------get glogic to find {;} courses-----
---(acad.id)----
create or replace function
	coreCoursePat(int) returns setof text
as 
$$
declare
	r text;
	k text;
	g text;
	s text;
	n int;
begin
SELECT gdefby into g FROM acad_object_groups WHERE id = $1;
if(g = 'enumerated')then
	SELECT glogic into g FROM acad_object_groups WHERE id = $1;
	if(g = 'and')then
		for r in 
			SELECT s.code
			FROM subjects as s 
			WHERE id IN (SELECT subject
				     FROM subject_group_members
				     WHERE ao_group = $1)
			ORDER BY s.code
		loop
			return next r;
		end loop;
	elsif(g = 'or')then
		k = '(';
		for r in
			SELECT s.code
			FROM subjects as s
			WHERE id IN (SELECT subject FROM subject_group_members WHERE ao_group = $1)
		loop
			k = k || r || '|';
		end loop;	
		SELECT regexp_replace(k,'\|$',')') into k;
		return next k;
	end if;
	for n in
		SELECT id 
		FROM acad_object_groups
		WHERE parent = $1
	loop
	        SELECT glogic into g FROM acad_object_groups WHERE id = n;
		if(g = 'and')then
			for k in
				SELECT s.code
				FROM subjects as s
				WHERE id IN (SELECT subject
					     FROM subject_group_members
					     WHERE ao_group = n)
				ORDER BY s.code
			loop
				return next k;
			end loop;
		elsif(g = 'or')then
			s = '(';
			for k in
                        	SELECT s.code
                        	FROM subjects as s
                        	WHERE id IN (SELECT subject FROM subject_group_members WHERE ao_group = n)
			loop
				s = s || k || '|';
			end loop;
			SELECT regexp_replace(s,'\|$',')') into s;
			return next s;
		end if;
	end loop;
elsif(g = 'pattern')then
	return query SELECT * FROM getsubpat($1);	
end if;
end;
$$ language plpgsql
;

-----------------

create or replace function
	decodePat(text) returns table(code text)
as
$$
declare
	r text;
begin	
	code = $1;
	if($1 ~ '\(')then
		SELECT regexp_replace($1,'(\(|\))','','g') into r;
		return query SELECT regexp_split_to_table(r,'\|');
	else
		return next;
	end if;
end;
$$ language plpgsql
;

----(code,UG,nexttermid)-----
create or replace function
	checkValidNextTerm(text,text,int) returns int
as
$$
declare
	sub int;
	k text;
	g text;
	m text;
	pg text;
	r int;
begin
	r = 0;
	SELECT id into sub FROM subjects WHERE code::text ~ $1;
	if(sub is not null)then
		SELECT EXISTS (SELECT * FROM courses WHERE subject = sub and semester = $3) into k;
		SELECT EXISTS (SELECT * FROM subject_prereqs WHERE subject = sub) into g;
		if(k = 't')then
			if(g = 'f')then 	
				SELECT EXISTS (SELECT * FROM subjects WHERE id = sub and career = $2) into pg;
				if(pg = 't') then r = sub; end if;
			else
	                	SELECT EXISTS (SELECT * FROM subject_prereqs WHERE subject = sub and career = $2) into m;
				if(k = 't' and m = 't')then
					r = sub;
				end if;
			end if;
		end if;
	end if;
	return r;
end;
$$ language plpgsql
;

------------------(r.id,s.id,currterm,nextterm,career)  for core course-----------
create or replace function
	rulesCourses(int,int,int,int,text) returns setof rules_course
as
$$
declare
	ac int;
	k text;
	r text;
	sub text;
	ty text;
	e int;
	rule_exist text;
	sub_id int;
	existNextTerm int;
	course rules_course;
begin
	course.code = null;
	course.prereq_rid = null;
	SELECT ao_group into ac FROM rules WHERE id = $1;
	for r in
		SELECT * FROM coreCoursePat(ac)
	loop
		SELECT EXISTS (SELECT * FROM transtable($2,$3) WHERE code ~ r) into k;
		if(k = 'f')then
			for sub in
				SELECT * FROM decodepat(r)
			loop
				existNextTerm = checkValidNextTerm(sub,$5,$4);		
				if(existNextTerm > 0)then
					course.code = sub;
					SELECT excluded into e FROM subjects WHERE id = existNextTerm;
					course.exclude = e;
					
					SELECT EXISTS (SELECT rule FROM subject_prereqs WHERE subject = existNextTerm and career = $5) INTO rule_exist;
					if(rule_exist = 't')then
						for e in
	                                        	SELECT rule FROM subject_prereqs WHERE subject = existNextTerm and career = $5
						loop 
							SELECT type into ty FROM rules WHERE id = e;
							if(ty != 'WM')then
								course.prereq_rid = e;
							end if;
						end loop;
					else
						course.prereq_rid = null;
					end if;
					return next course;
				end if;
			end loop; 
		end if;
	end loop;

end;
$$ language plpgsql
;
-----add uoc,wam----
create or replace function
	afterPreCourse(int,int,int,int,text,int,int) returns setof rules_course	
as
$$
declare
	ag int;
	def text;
	sub TranscriptRecord;
	pre int;
	mi int;
	k text;
	t text;
	r rules_course;
begin
	for r in
		SELECT DISTINCT * FROM rulesCourses($1,$2,$3,$4,$5)
	loop
		if(r.prereq_rid is null)then
			return next r;
		else
			SELECT type into t FROM rules WHERE id = r.prereq_rid;
			if(t = 'MR')then
				SELECT min into mi FROM rules WHERE id = r.prereq_rid;
				if(mi < $6)then
					return next r;
				end if;
			elsif(t = 'WM')then
        			SELECT min into mi FROM rules WHERE id = r.prereq_rid;
				if(mi < $7)then
					return next r;
				end if;
			else
			SELECT ao_group into ag FROM rules WHERE id = r.prereq_rid;
			SELECT gdefby into def FROM acad_object_groups WHERE id = ag;

			for sub in
				SELECT * FROM transtable($2,$3)
			loop
				if(def = 'pattern')then 
					SELECT * into pre FROM subjectInGroup(sub.code,ag);
					if(pre = 1)then return next r; end if;
				else
					SELECT EXISTS (SELECT * FROM subject_emufinder(ag) WHERE subject_emufinder = sub.code) into k;
					if(k = 't') then return next r;end if;
				end if;
			end loop;
		end if;
end if;
	end loop;
end;
$$ language plpgsql
;


create or replace function
	afterExCourse(int,int,int,int,text,int,int) returns setof text	
as
$$
declare
	def text;
	sub TranscriptRecord;
	have int;
	pre int;
	k text;
	r rules_course;
begin
	for r in
		SELECT DISTINCT * FROM afterPreCourse($1,$2,$3,$4,$5,$6,$7) ORDER BY code
	loop
		if(r.exclude is null)then
			return next r.code;
		else
			have = 0;
			SELECT gdefby into def FROM acad_object_groups WHERE id = r.exclude;
			for sub in
				SELECT * FROM transtable($2,$3)
			loop
				if(def = 'pattern')then 
					SELECT * into pre FROM subjectInGroup(sub.code,r.exclude);
					if(pre = 1)then have = 1; exit; end if;
				else
					SELECT EXISTS (SELECT * FROM subject_emufinder(r.exclude) WHERE subject_emufinder = sub.code) into k;
					if(k = 't') then have = 1; exit;end if;
				end if;
			end loop;
			if(have = 0)then
				return next r.code;
			end if;
		end if;
	end loop;
end;

$$ language plpgsql
;


--------get MR pattern(r.id)---
create or replace function
	getMRPat(int) returns setof text
as
$$
declare
	ag int;
begin
	SELECT ao_group into ag FROM rules WHERE id = $1;
	return query SELECT * FROM getdefinition(ag);
end;
$$ language plpgsql
;


















