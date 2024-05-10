STACK_NAME := "vault"
make:
	@echo "make [deploy|remove|clean]"

deploy:
	docker stack deploy -c docker-compose.yml --detach=true --with-registry-auth $(STACK_NAME)

remove:
	docker stack rm $(STACK_NAME)

clean:
	@echo "Cleaning volumes..."
	@docker volume ls -q  | grep vault- | xargs docker volume rm
