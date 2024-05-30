##The ifeq ($(RUN_LOCALLY), true) condition checks if the variable RUN_LOCALLY is set to true.
##If it is, the RUN target is defined without any command. This means that
##if RUN_LOCALLY is set to true, the application will be run locally without using Docker Compose.

##If RUN_LOCALLY is not set to true, the RUN target is defined with the command ${COMPOSE} run --rm puma. This command uses Docker Compose to run the puma service in a new container. The --rm flag ensures that the container is automatically removed after it exits.

##To summarize, this code snippet allows you to control how the application is run based on the value of the RUN_LOCALLY variable. If RUN_LOCALLY is set to true, the application will be run locally. Otherwise, it will be run using Docker Compose.
##@ Environment
ifeq ($(RUN_LOCALLY), true)
define RUN

endef
else
define RUN
	${COMPOSE} run --rm puma
endef
endif

COMPOSE := docker-compose -f docker-compose.yml
DOCKER_SYNC := docker-sync.yml
##@ Developing

.PHONY: install
install: build setup ## Install dependencies and configure project

.PHONY: build
build: .stamps/dockerfile.stamp ## Build the docker images
.stamps/dockerfile.stamp: .stamps scripts/environment/Dockerfile
	${COMPOSE} build && touch $@

.PHONY: setup
setup: sync ## Run setup script
	${RUN} bin/setup

.PHONY: run
run: sync ## Run the docker development stack
	${COMPOSE} up --remove-orphans

.PHONY: stop
stop: ## Stop the docker development stack
	${COMPOSE} down
	docker-sync stop
	# docker-sync stop -c ${DOCKER_SYNC}

.PHONY: migrate
migrate: sync ## Run the pending migrations
	${RUN} bin/rails db:migrate

.PHONY: rollback
rollback: sync ## Rollback the last migration
	${RUN} bin/rails db:rollback:primary step=1

.PHONY: puma
puma: sync ## Run puma with docker
	${COMPOSE} up puma

.PHONY: attach-puma
attach-puma: ## Attach to the running puma container
	docker attach `${COMPOSE} ps -q puma`

.PHONY: shell
shell: sync ## Start a bash shell in puma image
	${RUN} bash

.PHONY: console
console: sync ## Start a rails console
	${RUN} bin/rails console

.PHONY: sidekiq
sidekiq: sync ## Run sidekiq with docker
	${COMPOSE} up sidekiq

.PHONY: attach-sidekiq
attach-sidekiq: ## Attach to the running sidekiq container
	docker attach `${COMPOSE} ps -q sidekiq`

.PHONY: elshell
elshell: sync ## Start a bash shell on elasticsearch image
	${COMPOSE} run --rm elasticsearch bash

.PHONY: test
test: sync ## Run the unit specs
	${RUN} bin/rspec

.PHONY: lint
lint: sync ## Lint ruby code with rubocop
	${RUN} bin/rubocop

.PHONY: lint-fix
lint-fix: sync ## Lint ruby code with rubocop
	${RUN} bin/rubocop -a

.PHONY: lint-file
lint-file: sync ## Lint a single file with rubocop
	${RUN} bin/rubocop -a ${file}

.PHONY: check-boundaries
check-boundaries: sync ## Check cross-component dependencies
	${RUN} bin/bundle exec packwerk check

##@ Doc

.PHONY: routes
routes: sync ## List rails routes
	${RUN} bin/rails routes

.PHONY: swagger-generate
swagger-generate: sync ## Generate swagger API files
	${RUN} bin/rake rswag:specs:swaggerize SWAGGER_ROOT="swagger/" PATTERN="spec/requests/swagger/**/*_spec.rb"

.PHONY: swagger-validate-file
swagger-validate-file: swagger-generate
	docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli validate -i /local/${file}

.PHONY: start-admin
latest_db_dump = $(shell aws s3 ls s3://staging-pdx-886862221201-s3-db-dump/ --recursive | grep 'web-staging' | sort | tail -n 1 | awk '{print $$4}')

.PHONY: download-latest-db-dump
download-latest-db-dump: ## Dl seed data from s3 (run manually before `install` or `setup` for fresh data, requires AWS env variables)
	-@aws s3 cp s3://staging-pdx-886862221201-s3-db-dump/${latest_db_dump} db/dump.sql.gz --region us-west-2 && gunzip db/dump.sql.gz

start-kibana: ## Start a kibana docker container connected to elasticsearch
	${COMPOSE} -f docker-compose.admin.yml up -d kibana

stop-kibana: ## Stop the kibana container
	${COMPOSE} -f docker-compose.admin.yml stop kibana

# pass the arguments inside an array, e.g. args="[arg1,arg2,...argn]"
.PHONY: rake
rake: ## Run Rake task
	${RUN} bin/rake ${task}${args}

##@ Utility

.PHONY: clean
clean: ## Clean everything
	rm -rf .stamps
	rm -rf ./tmp
	rm -rf ./log
	rm -rf ./db/dump.sql
	rm -rf ./db/dump.sql.gz
	${COMPOSE} -f docker-compose.admin.yml down -v
	docker-sync clean

.PHONY: sync
sync: ## Start docker-sync for project
	docker-sync start -c ${DOCKER_SYNC}

.stamps: Makefile ## Create directory for Makefile stamps
	@mkdir -p $@
