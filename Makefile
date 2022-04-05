SHELL = /bin/sh
# Makefile for transpiling node.js AWS Lambda function with TypeScript, testing 
# with `jest`, and deploying with `terraform`
.PHONY: all clean type-check destroy-all deploy output watch-test test tf-lint

# Install `babel-cli` in a project to get the transpiler.
tsc := node_modules/.bin/tsc

this-makefile := $(lastword $(MAKEFILE_LIST))
srctree := $(realpath $(dir $(this-makefile)))

# This target also depends on the `node_modules/` directory, so that `make`
# automatically runs `npm install` if `package.json` has changed.
all: type-check plan-json build coverage node_modules build/node_modules test tf-lint tf-fmt

# This rule tells `make` how to transpile a source file using `tsc`.
# Transpiled files will be written to `build/`
build: src node_modules tsconfig.json
	$(tsc) --build

build/node_modules: build package-lock.json
	cp package*json build/ && \
	cd build/ && \
	NODE_ENV=production npm ci

clean:
	rm -rf build *tfplan* node_modules .terraform coverage

package-lock.json:
	npm install
	touch node_modules

# This rule informs `make` that the `node_modules/` directory is out-of-date
# after changes to `package.json` or `package-lock.json`, and instructs `make` 
# on how to install modules to get back up-to-date.
node_modules: package.json package-lock.json
	npm ci
	touch node_modules

# Check TypeScript types
type-check: node_modules tsconfig.json
	$(tsc) --noEmit

# Run TypeScript, watching for changes to files
watch-types: node_modules tsconfig.json
	$(tsc) --watch

# Initialize the terraform project. This command creates the `.terraform` 
# folder and downloads/saves the declared `terraform` providers within, along
# with cloud provider specific configuration or metadata
.terraform:
	terraform init

# Format the terraform code
tf-fmt: .terraform
	terraform fmt -check

tf-lint: .terraform
	terraform validate

tfplan.bin: build/node_modules .terraform tf-fmt tf-lint
	terraform plan -out tfplan.bin

# Create the terraform plan and save it to a file in order to apply after 
# review
plan: tfplan.bin
	
# Create a JSON representation of the `terraform` plan output
plan-json: tfplan.bin
	terraform show -json tfplan.bin > tfplan.json

# Deploy to AWS using the plan we created using `terraform`
deploy: plan
	terraform apply tfplan.bin

# Display the `terraform` outputs (declared in `outputs.tf`)
output: plan
	terraform output

destroy.tfplan.bin: .terraform
	terraform plan -destroy -out destroy.tfplan.bin

# Create a plan to destroy the AWS environment using `terraform`
destroy: destroy.tfplan.bin
	
# Apply the changes to destroy the AWS environment.
destroy-confirm: destroy.tfplan.bin
	terraform apply destroy.tfplan.bin

# Generate a test coverage report using `jest`
coverage: node_modules
	npx jest --coverage

# Run tests using `jest`
test: node_modules
	npx jest

# Run `jest` and watch for changes to files
watch-test: package-lock.json node_modules
	npx jest --watch

PHONY += help
help:
	@echo  'Cleaning targets:'
	@echo  '  clean		  - Remove generated files'
	@echo  ''
	@echo  'Other generic targets:'
	@echo  '  all             - Build all targets marked with [*]'
	@echo  ''
	@echo  'TypeScript targets:'
	@echo  '* build           - Transpile TypeScript into JavaScript'
	@echo  '* type-check      - Check types'
	@echo  '  watch-types     - Run TypeScript type-checker in watch mode, watching for file changes'
	@echo  '* test            - Run tests using jest'
	@echo  '  watch-test      - Run jest in watch mode, watching for file changes'
	@echo  '* coverage        - Run tests and write a report of test coverage'
	@echo  ''
	@echo  'terraform targets:'
	@echo  '* tf-fmt          - Format terraform code using terraform built-in tool'
	@echo  '* tf-lint         - Check the terraform code for errors'
	@echo  '* plan            - Generate a terraform plan'
	@echo  '  plan-json       - Create a copy of the terraform plan in JSON format'
	@echo  '  deploy          - Deploy the environment'
	@echo  '  output          - Show terraform outputs'
	@echo  '  destroy         - Generate a plan to destroy the environment'
	@echo  '  destroy-confirm - Confirm and apply destroy plan, destroying the current environment using terraform'
	@echo  ''
	@echo  'Execute "make" or "make all" to build all targets marked with [*] '
	@echo  'For further info see the ./README file'

