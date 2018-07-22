CREATE TABLE G(
	b int,
	e text
	primary key(b)
);

CREATE TABLE F(
	a int,
	b int not null,
	c text,
	d text,
	primary key(a)
	foreign key(b) references G(b)
);
