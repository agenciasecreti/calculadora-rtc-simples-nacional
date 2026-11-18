FROM eclipse-temurin:21-jdk AS build
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN chmod +x mvnw
ARG FLYWAY_REPO=https://github.com/ReceitaFederal/calculadora-rtc-regime-regular.git
RUN git clone --depth 1 "$FLYWAY_REPO" /tmp/rr && cp -r /tmp/rr/flyway ./flyway
RUN mkdir -p ./calculadora/db && \
    ./mvnw flyway:migrate -Dflyway.configFiles=./flyway/flyway-pro.conf --batch-mode --errors && \
    ls -lah ./calculadora/db/calculadora-pro.db
RUN ./mvnw clean package -DskipTests --batch-mode

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/api-simples-nacional.jar ./app.jar
COPY --from=build /app/calculadora/db ./calculadora/db
ENV TZ=America/Sao_Paulo
EXPOSE 8082
CMD ["sh", "-c", "java -Dspring.profiles.active=offline -Dserver.address=:: -Dserver.port=${PORT:-8082} -jar app.jar"]
