.PHONY: up down logs clean rebuild ps restart

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

clean:
	docker-compose down -v --remove-orphans

rebuild:
	docker-compose up -d --build

ps:
	docker-compose ps

restart:
	docker-compose restart

shell-%:
	docker-compose exec $* sh
