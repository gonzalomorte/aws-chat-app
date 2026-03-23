# Stage 1: Build the application
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /app
COPY . .
# Mount cache volume for Gradle dependencies to speed up the build [cite: 91]
RUN --mount=type=cache,target=/root/.gradle ./gradlew clean build -x test

# Stage 2: Run the application 
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
# Copy the built JAR from the first stage
COPY --from=build /app/build/libs/ChatApp-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 5000
ENTRYPOINT ["java", "-jar", "app.jar"]