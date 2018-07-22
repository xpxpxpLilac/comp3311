CREATE TABLE Horse(
	name text not null,
	color text,
	age integer check (age > 0),
	primary key(name)
);
CREATE TABLE Stallion(
	name text not null,
	children integer,
	studFee float,
	primary key(name) references Horse(name)
);
CREATE TABLE Gelding(
	name text not null,
	primary key(name references Horse(name))
);
CREATE TABLE Race(
	id integer not null,
	rid integer not null,
	name text,
	when date,
	primary key(id),
	foreign key(rid) references racecourse(id)
);
CREATE TABLE RACECOURSE(
	id integer not null,
	name text,
	location text,
	primary key(id)
);
CREATE TABLE Enter(
	name text not null,
	id integer not null,
	position text,
	primary key(name,id),
	foreign key(name) references Horse(name),
        foreign key(id) references Race(id)
);
