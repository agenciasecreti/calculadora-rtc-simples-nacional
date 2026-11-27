FROM eclipse-temurin:25-jdk AS build
# curl: o mvnw 3.2.0 baixa o maven-wrapper.jar com curl ou wget, e a imagem temurin 25 não traz nenhum dos dois
# (sem eles o mvnw falha com ClassNotFoundException: MavenWrapperMain).
RUN apt-get update && apt-get install -y --no-install-recommends git curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Base de regras da Receita FIXADA numa versão. Regras e app andam juntos:
# app 1.0.2 <-> regras 1.7.2. Clonar o main sem versão juntou regras novas com
# um app antigo em 22/11/2026 e todo cálculo passou a dar HTTP 500.
# Para atualizar: troque as duas linhas juntas (tag e commit) e teste antes.
ARG FLYWAY_REPO=https://github.com/ReceitaFederal/calculadora-rtc-regime-regular.git
ARG FLYWAY_TAG=1.7.2
ARG FLYWAY_COMMIT=39363aa84103c6d58f7e8e76acb2f592691ec382

# O pom do app (1.0.x) não tem mais o flyway-maven-plugin: a migração roda com
# o pom e o mvnw do próprio repositório de regras.
RUN git clone --depth 1 --branch "$FLYWAY_TAG" "$FLYWAY_REPO" /rr && \
    test "$(git -C /rr rev-parse HEAD)" = "$FLYWAY_COMMIT" && \
    cd /rr && chmod +x mvnw && mkdir -p ./calculadora/db && \
    ./mvnw flyway:migrate -Dflyway.configFiles=./flyway/flyway-pro.conf --batch-mode --errors && \
    ls -lah ./calculadora/db/calculadora-pro.db

WORKDIR /app
COPY . .
RUN chmod +x mvnw && ./mvnw clean package -DskipTests --batch-mode

FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /app/target/api-simples-nacional.jar ./app.jar
COPY --from=build /rr/calculadora/db ./calculadora/db
ENV TZ=America/Sao_Paulo
EXPOSE 8082
# -XX:-UseBASE64Intrinsics: mitigação do aviso de segurança do OpenJDK de 17/11/2026 (CHANGELOG 1.0.1).
CMD ["sh", "-c", "java -XX:-UseBASE64Intrinsics -Dspring.profiles.active=offline -Dserver.address=:: -Dserver.port=${PORT:-8082} -jar app.jar"]
