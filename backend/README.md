# ShopWeb Backend

Backend API for Computer Parts E-commerce System built with Spring Boot.

## Technology Stack

- **Java**: 17
- **Spring Boot**: 3.2.0
- **Database**: Microsoft SQL Server
- **Authentication**: JWT (JSON Web Tokens)
- **Build Tool**: Maven

## Project Structure

```
backend/
├── src/
│   ├── main/
│   │   ├── java/com/shopweb/
│   │   │   ├── ShopWebApplication.java      # Main application class
│   │   │   ├── config/                       # Configuration classes
│   │   │   │   ├── DatabaseConfig.java      # Database connection config
│   │   │   │   └── SecurityConfig.java      # Security & JWT config
│   │   │   ├── controller/                   # REST Controllers
│   │   │   │   ├── customer/                # Customer web endpoints
│   │   │   │   ├── staff/                   # Staff dashboard endpoints
│   │   │   │   ├── manager/                 # Manager dashboard endpoints
│   │   │   │   └── admin/                   # Admin panel endpoints
│   │   │   ├── service/                      # Business logic
│   │   │   ├── repository/                   # Database repositories
│   │   │   ├── model/entity/                # JPA entities
│   │   │   ├── dto/                         # Data Transfer Objects
│   │   │   └── exception/                   # Custom exceptions
│   │   └── resources/
│   │       ├── application.properties       # Main config
│   │       └── application-dev.properties   # Dev environment config
│   └── test/                                # Test files
└── pom.xml                                  # Maven dependencies
```

## Prerequisites

- Java 17 or higher
- Maven 3.6+
- Microsoft SQL Server (2019 or higher)

## Database Setup

### 1. Install SQL Server

Download and install [SQL Server](https://www.microsoft.com/sql-server/sql-server-downloads) or use Docker:

```bash
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=YourPassword123!" \
  -p 1433:1433 --name sqlserver \
  -d mcr.microsoft.com/mssql/server:2019-latest
```

### 2. Create Database

```sql
CREATE DATABASE shopweb;
```

## Configuration

### Environment Variables

Create environment variables or update `application.properties`:

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_URL` | SQL Server connection URL | `jdbc:sqlserver://localhost:1433;databaseName=shopweb;encrypt=true;trustServerCertificate=true` |
| `DB_USERNAME` | Database username | `sa` |
| `DB_PASSWORD` | Database password | `your_password` |
| `JWT_SECRET` | Secret key for JWT tokens | `your_secret_key_change_this_in_production` |
| `JWT_EXPIRATION` | JWT expiration time (ms) | `86400000` (24 hours) |

### Example: Setting Environment Variables

**Linux/Mac:**
```bash
export DB_URL="jdbc:sqlserver://localhost:1433;databaseName=shopweb;encrypt=true;trustServerCertificate=true"
export DB_USERNAME="sa"
export DB_PASSWORD="YourPassword123!"
export JWT_SECRET="your_very_secure_secret_key_here"
```

**Windows:**
```cmd
set DB_URL=jdbc:sqlserver://localhost:1433;databaseName=shopweb;encrypt=true;trustServerCertificate=true
set DB_USERNAME=sa
set DB_PASSWORD=YourPassword123!
set JWT_SECRET=your_very_secure_secret_key_here
```

## Installation & Running

### 1. Clone the repository
```bash
git clone https://github.com/Pluong371/ShopWeb.git
cd ShopWeb/backend
```

### 2. Configure database connection
Update `src/main/resources/application.properties` or set environment variables.

### 3. Build the project
```bash
mvn clean install
```

### 4. Run the application
```bash
mvn spring-boot:run
```

Or with a specific profile:
```bash
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

### 5. Run with Docker (Optional)
```bash
# Build Docker image
docker build -t shopweb-backend .

# Run container
docker run -p 8080:8080 \
  -e DB_URL="jdbc:sqlserver://host.docker.internal:1433;databaseName=shopweb" \
  -e DB_USERNAME="sa" \
  -e DB_PASSWORD="YourPassword123!" \
  shopweb-backend
```

## API Documentation

The application will be available at: `http://localhost:8080`

### API Endpoints by Subsystem

#### 1. Customer Web (`/api/customer/`)
- Product browsing and filtering
- Shopping cart management
- Order placement and tracking

#### 2. Staff Dashboard (`/api/staff/`)
- Task management
- Order picking (with serial number scanning)
- Inventory discrepancy reporting

#### 3. Manager Dashboard (`/api/manager/`)
- Product management
- Staff coordination
- Stock control
- Order management (confirm/cancel/refund)

#### 4. Admin Panel (`/api/admin/`)
- User management
- Role and permission management
- Audit log viewing

## Testing

Run tests:
```bash
mvn test
```

## Database Schema

The application uses JPA/Hibernate for ORM. Database tables will be automatically created/updated based on entity definitions when running the application.

### Core Entities:
- **User**: Customer and system users
- **Product**: Computer parts products
- **Category**: Product categories (CPU, RAM, VGA, etc.)
- **Cart & CartItem**: Shopping cart
- **Order & OrderItem**: Orders
- **Assignment**: Staff tasks
- **Stock & StockAlert**: Inventory management
- **Role & AuditLog**: Security and auditing

## Troubleshooting

### Database Connection Issues

1. **Connection refused**: Ensure SQL Server is running
2. **Login failed**: Verify username and password
3. **Certificate error**: Use `trustServerCertificate=true` in connection string

### Port Already in Use

Change the port in `application.properties`:
```properties
server.port=8081
```

## Development

### Code Style
- Follow Java naming conventions
- Use Lombok annotations to reduce boilerplate
- Document public APIs with JavaDoc

### Adding New Features
1. Create entity in `model/entity/`
2. Create repository in `repository/`
3. Create service in appropriate subsystem folder in `service/`
4. Create controller in appropriate subsystem folder in `controller/`

## License

This project is part of a university assignment.
