# Backend Structure Notes

This document summarizes the key findings from the initial analysis of the `Server/onettoo` backend project.

- **Main Module & Base Package**: The primary backend service is a standard Spring Boot application. The base package is `com.cloud.onettoo`.

- **Core Business Logic Location**: All relevant business logic is located within the `modules` package: `src/main/java/com/cloud/onettoo/modules/`.

- **Key Entities**:
    - **Share Entity**: `modules/model/GuanzhiDO.java` (Note: "Share" is referred to as "Guanzhi" internally).
    - **User Entity**: `modules/model/UserDO.java`

- **Core Layers**:
    - **Controllers**: Located in `modules/rest/`. Expect `GuanzhiController.java` and `UserController.java`.
    - **Services**: Located in `modules/service/`. Key interfaces are `GuanzhiService.java` and `UserService.java`.
    - **Mappers (DAO)**: Located in `modules/mapper/`. Expect `GuanzhiMapper.java` and `UserMapper.java`.

- **Key Technologies & Utilities**:
    - **Database Interaction**: The project uses **MyBatis-Plus**.
    - **Caching**: **Redis** is used, with the `Jedis` client.
    - **Authentication**: **Spring Security with JWT** is used for authentication. The current user's ID can be retrieved from the security context.
    - **Scheduled Tasks**: The specific implementation (e.g., `@Scheduled`) needs to be confirmed.
    - **Database Migration**: The project does not use Flyway or Liquibase. Migrations must be handled with manual SQL scripts.
