FROM public.ecr.aws/docker/library/python:3.13-alpine

# The pipeline passes the Git tag version, for example v1.0. The page shows it.
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION PYTHONUNBUFFERED=1

COPY src/server.py /app/server.py

USER nobody
EXPOSE 8080
CMD ["python", "/app/server.py"]
