SHELL = /bin/sh
# Makefile for transpiling with Babel in a Node app, or in a client- or
# server-side shared library.

.PHONY: all clean type-check destroy-all deploy output

# Install `babel-cli` in a project to get the transpiler.
tsc := node_modules/.bin/tsc

# Identify modules to be transpiled by recursively searching the `src/`
# directory.
src_files := $(shell find src/ -name '*.ts' -o -name '*.js')

# Building will involve copying every `.js` file from `src/` to a corresponding
# file in `lib/` with a `.js.flow` extension. Then we will run `babel` to
# transpile copied files, where the transpiled file will get a `.js` extension.
# This assignment computes the list of transpiled `.js` that we expect to end up;
# and we will work backward from there to figure out how to build them.
transpiled_files := $(src_files:src/%.ts=build/%.js)

# Putting each generated file in the same directory with its corresponding
# source file is important when working with Flow: during type-checking Flow
# will look in npm packages for `.js.flow` files to find type definitions. So
# putting `.js` and `.js.flow` files side-by-side is how you export type
# definitions from a shared library.

# This target also depends on the `node_modules/` directory, so that `make`
# automatically runs `yarn install` if `package.json` has changed.
all: type-check plan-json node_modules build

# This rule tells `make` how to transpile a source file using `babel`.
# Transpiled files will be written to `lib/`
build: src node_modules
	$(tsc) --build

build/node_modules: build
	cp package*json build/ && \
	cd build/ && \
	NODE_ENV=production npm ci

# Transpiling one file at a time makes incremental transpilation faster:
# `make` will only transpile source files that have changed since the last
# invocation.

clean:
	rm -rf build *tfplan* node_modules .terraform

# This rule informs `make` that the `node_modules/` directory is out-of-date
# after changes to `package.json` or `yarn.lock`, and instructs `make` on how to
# install modules to get back up-to-date.
node_modules: package.json package-lock.json
	npm install
	touch node_modules


type-check: node_modules
	$(tsc) --noEmit


.terraform:
	terraform init

tfplan.bin: build/node_modules .terraform
	terraform plan -out tfplan.bin

plan: tfplan.bin
	

plan-json: tfplan.bin
	terraform show -json tfplan.bin > tfplan.json

deploy: plan
	terraform apply tfplan.bin

output: plan
	terraform output

destroy.tfplan.bin: .terraform
	terraform plan -destroy -out destroy.tfplan.bin

destroy: destroy.tfplan.bin
	

destroy-all: destroy.tfplan.bin
	terraform apply destroy.tfplan.bin

