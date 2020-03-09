# ElasticStack all-on-one container with ReadonlyREST Enterprise 

This project is designed to install ElasticSearch, Kibana and ReadonlyREST Enterprise trial edition.

## First steps

```
make run
```

Open your browser to http://localhost:5601 and login with admin:admin.

## Makefile targets

```
Elasticstack: 0.1.0

Usage:
  make <target>

Docker
  build            build the container
  shell            get a shell in the container
  run              get a shell in the container
  attach           Attach
  stop             get a shell in the container
  clean            Clean docker container and image

Helpers
  cloc             Show Lines of Code analysis
  help             Display this help
```

## Credits
This project is based on the great work of Greg Trahair 
