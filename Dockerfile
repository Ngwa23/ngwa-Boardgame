# --------
# Stage 0: build with Maven (Java 11)
# --------
FROM maven:3.9.6-eclipse-temurin-11 AS build
WORKDIR /workspace

# Copy pom and maven wrapper first to cache dependencies
COPY pom.xml mvnw* ./
#COPY .mvn .mvn

# Download dependencies before copying sources to leverage cache
RUN mvn -B -ntp dependency:go-offline

# Copy source and build (skip tests for faster builds; remove -DskipTests to run tests)
COPY src ./src
RUN mvn -B -ntp package -DskipTests

# The built jar will be at /workspace/target/*.jar (standard Maven layout for Spring Boot)
# --------
# Stage 1: debug-friendly slim runtime (optional)
# Build with: docker build --target runtime-slim -t bgame:slim .
# --------
FROM eclipse-temurin:11-jre-jammy AS runtime-slim
# create non-root user for runtime
RUN useradd --create-home --shell /bin/false appuser
WORKDIR /app

# Copy the fat/executable jar from the build stage
COPY --from=build /workspace/target/*.jar /app/app.jar

EXPOSE 8080

USER appuser
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

# --------
# Stage 2: production Distroless runtime (recommended)
# Build with: docker build --target runtime-distroless -t bgame:distroless .
# Run with:  docker run -p 8080:8080 bgame:distroless
# --------
FROM gcr.io/distroless/java11-debian11:nonroot AS runtime-distroless
WORKDIR /app

# Copy only the jar into the minimal image
COPY --from=build /workspace/target/*.jar /app/app.jar

EXPOSE 8080

# Distroless images are minimal and already run as non-root; entrypoint must be JSON array
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
