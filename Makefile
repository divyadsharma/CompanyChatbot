# # Makefile

.PHONY: build up shell

build:
	docker-compose build

up: build
	docker-compose up --build

 shell: up
	@echo "Opening shell..."
	/bin/sh

# .PHONY: build up shell

# build:
# 	@echo "Building the project..."
# 	# Add your build commands here
# 	# e.g., docker-compose build

# up: build
# 	@echo "Starting the project..."
# 	# Add your up commands here
# 	# e.g., docker-compose up -d

# shell: up
# 	@echo "Opening shell..."
# 	/bin/sh