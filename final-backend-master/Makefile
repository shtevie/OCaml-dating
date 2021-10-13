.PHONY: test clean seed

default: build
	OCAMLRUNPARAM=b utop

build:
	dune build

test:
	ENV=test dune runtest

dev:
	ENV=dev dune exec backend

seed:
	ENV=dev dune exec seed

zip:
	zip backend.zip *.ml* *.json *.sh _tags .merlin .ocamlformat .ocamlinit LICENSE Makefile	
	
docs:
	dune build @doc

clean:
	dune clean
